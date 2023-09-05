//
//  Decoder.h
//  chronos
//
//  Created by Rhys Balevicius.
//

#ifndef Decoder_h
#define Decoder_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Decoder : NSObject

- (id) init;
- (int) decode: (long) totalLength
   forDetected: (int8_t*) detected
      asOutput: (int8_t*) output;

@end

NS_ASSUME_NONNULL_END

#endif /* Decoder_h */
