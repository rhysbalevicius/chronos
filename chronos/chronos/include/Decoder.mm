//
//  Decoder.mm
//  chronos
//
//  Created by Rhys Balevicius.
//

#import <Foundation/Foundation.h>
#import <vector>
#include "Reed-Solomon/rs.hpp"
#import "Decoder.h"

constexpr int kPayloadLength = 4;

@implementation Decoder

- (id) init
{
    self = [super init];
    
    return self;
}

- (int) decode: (long) totalLength
   forDetected:(int8_t *)detected
      asOutput:(int8_t *)output
{
    RS::ReedSolomon<kPayloadLength, 4> rs {};
    std::vector<std::uint8_t> encodedData (totalLength);
    std::vector<std::uint8_t> decodedData (totalLength);
    std::fill(decodedData.begin(), decodedData.end(), 0);
    
    for (int i = 0; i < totalLength; i++)
    {
        encodedData[i] = (detected[2*i + 1] << 4) + detected[2*i + 0];
    }
    
    if (rs.Decode(encodedData.data(), decodedData.data()) == 0)
    {
        if (decodedData[0] != 0)
        {
            for (int i = 0; i < kPayloadLength; i++)
            {
                output[i] = decodedData[i];
            }
            
            return 1;
        }
    }
    
    return 0;
}

@end
