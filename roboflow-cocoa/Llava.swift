import Foundation
import LlavaKitShim
import JSONSchema

struct LlavaPrediction: Decodable {
    let classLabel: String
    let confidenceScore: Float
}

@globalActor struct Llava {
    static var shared: ActorType = .init()
    
    actor ActorType {
        
        //extension DataModel {
        func llavaPrediction(imagePaths: [String],
                             labels: [String],
                             hint: String? = nil) throws -> [LlavaPrediction] {
            let schema = try! JSONSerialization.jsonObject(with: """
            {
                "title": "confidence_scores",
                "description": "The highest ranking confidence you have that the label is the object",
                "type": "object",
                "properties": {
                    "classLabel": {
                        "type": "string",
                        "enum": \(labels)
                    },
                    "confidenceScore": {
                        "type": "number"
                    }
                }
            }
            """.data(using: .utf8)!, options: []) as! [String: Any]
            let converter = SchemaConverter(propOrder: [])
            _ = converter.visit(schema: schema, name: nil)
            let grammar = converter.formatGrammar()
            
            let prompt = """
            What object is highlighted and bounding boxed in this image?
            
            The response should be formatted as a JSON object with a key for "className" and a key for "confidenceScore".
            "className" is the label of the class that you are most confident that the object in question is.
            
            "confienceScore" is a number between 0.0 and 1.0, where 0 is when you are NOT confident that the highlighted object contains that label, and 1 is you are ABSOLUTELY confident that the saturated object contains that label e.g.,:
            
            {"classLabel": "car", confidenceScore: 0.8}
            """
            var outSize = Int32(0)
            #if os(macOS)
            let cpmParams = minicpm_params(n_gpu_layers: 32, n_batch: 2048, n_threads: 6)
            let ggmlModel = Bundle.main.path(forResource: "ggml-model-Q4_K_M", ofType: "gguf")!
            #else
            let cpmParams = minicpm_params(n_gpu_layers: 16, n_batch: 256, n_threads: 4)
            let ggmlModel = Bundle.main.path(forResource: "ggml-model-Q4_K_M", ofType: "gguf")!
            #endif
            
            // Convert Swift strings to C-style strings
            let cStringArray = imagePaths.map { strdup($0) }
            defer {
                // Free the strdup memory after use
                for cString in cStringArray {
                    free(cString)
                }
            }
            // Create an array of UnsafePointers
            var cStringPointers: [UnsafePointer<CChar>?] = cStringArray.map { UnsafePointer($0) }

            print("Running inference for labels:", labels)
            // Pass this array to the function as UnsafeMutablePointer
            let response = cStringPointers.withUnsafeMutableBufferPointer {
                test_minicpm(ggmlModel,
                             Bundle.main.path(forResource: "minicpm-mmproj-model-f16", ofType: "gguf")!,
                             prompt,
                             $0.baseAddress,
                             Int32(cStringArray.count),
                             grammar,
                             cpmParams,
                             &outSize)!
            }
            var predictions = [LlavaPrediction]()
            for i in 0..<cStringArray.count {
                let data = String(cString: response.advanced(by: i).pointee!)
                    .data(using: .utf8)!
                predictions.append(try JSONDecoder().decode(LlavaPrediction.self, from: data))
            }

            return predictions
        }
    }
    //}
}
