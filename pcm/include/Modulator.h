//
//  Modulator.h
//  lipsync
//
//  Created by Rhys Balevicius.
//

#import <Foundation/Foundation.h>
#import <vector>

NS_ASSUME_NONNULL_BEGIN

@interface Modulator : NSObject 
{
    @private
    int payloadFrames;
    int payloadFrameSize;
    int samplesPerFrame;
    int frequencyStart;
    float outputGain;
    std::vector<float> outputFrames;
    std::vector<float> currentFrame;
    std::vector<std::vector<float>> loSpectrum;
    std::vector<std::vector<float>> hiSpectrum;
    std::vector<std::uint8_t> eccPayload;
}

- (id) init;
- (void) dealloc;
- (void) generate_spectrum;
- (void) write_frame: (int) frame;
- (void) amplify_signal: (int) bit 
                 offset: (int) offset 
                residue: (int) residue;
- (void) generate_pcm_buffer: (std::vector<float>&) pcm 
                     message: (std::vector<uint8_t>&) message
                        size: (int) size;
@end

NS_ASSUME_NONNULL_END