//
//  meloTTS-Bridging-Header.h
//  meloTTS
//
//  Bridge between Swift and Objective-C++/C++
//

#ifndef meloTTS_Bridging_Header_h
#define meloTTS_Bridging_Header_h

// Import our TTS inference header
#import "MeloTTSInfer.h"

// Import ONNX Runtime headers
// Based on the official documentation, ONNX Runtime SPM should provide these headers
#import <onnxruntime.h>

#endif /* meloTTS_Bridging_Header_h */