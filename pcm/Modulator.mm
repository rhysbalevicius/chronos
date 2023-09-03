//
//  Modulator.mm
//  lipsync
//
//  Created by Rhys Balevicius.
//

#import <cmath>
#import "include/Modulator.h"
#import "include/Reed-Solomon/include/rs.hpp"

@implementation Modulator
- (id) init
{
    self = [super init];
  
    if (self)
    {
        payloadFrames    = 9;
        payloadFrameSize = 3;
        frequencyStart   = 350;
        samplesPerFrame  = 1024;
        outputGain       = 0.5f;
        eccPayload  .resize(256);
        currentFrame.resize(1024);
        outputFrames.resize(1024 * 1024 * sizeof (float));

        [self generate_spectrum];
    }
    
    return self;
}

- (void) dealloc 
{
    [super dealloc];
}

- (void) generate_pcm_buffer: (std::vector<float>&) pcm_buffer 
                     message: (std::vector<uint8_t>&) message 
                        size: (int) size
{
    std::fill(eccPayload.begin(), eccPayload.end(), 0);
    RS::ReedSolomon rsData = RS::ReedSolomon(4, 4);
    rsData.Encode(message.data(), eccPayload.data());

    for (int frameId = 0; frameId < 27; frameId++) 
    {
        [self write_frame: frameId];
    }

    int bufferSize = 27 * samplesPerFrame * sizeof (float);
    pcm_buffer.resize(bufferSize);
    std::memcpy(pcm_buffer.data(), outputFrames.data(), bufferSize);
}

- (void) write_frame: (int) frame
{
    std::fill(currentFrame.begin(), currentFrame.end(), 0.0f);
    int offset = std::floor(frame / payloadFrames) * payloadFrameSize;

    for (int i = 0; i < payloadFrameSize; i++)
    {
        int bit = eccPayload[offset + i];
        [self amplify_signal: bit % 16 offset: 32 * i      residue: frame % payloadFrames];
        [self amplify_signal: bit / 16 offset: 32 * i + 16 residue: frame % payloadFrames];
    }

    for (int i = 0; i < samplesPerFrame; i++) 
    {
        outputFrames[frame * samplesPerFrame + i] = currentFrame[i] / 6;
    }
}

- (void) amplify_signal: (int) bit offset: (int) offset residue: (int) residue
{
    auto amplify = [self](std::vector<float>& spec, int residue) 
    {
        float totalFrames = payloadFrames * samplesPerFrame;
        for (int i = 0; i < samplesPerFrame; i++)
        {
            float j = residue * samplesPerFrame + i;
            if (j < totalFrames / 5.0f) 
                currentFrame[i] += spec[i] * outputGain * j * 5.0f / totalFrames;
            else if (j > 4 * totalFrames / 5.0f) 
                currentFrame[i] += spec[i] * outputGain * 5.0f * (totalFrames - j) / totalFrames;
            else 
                currentFrame[i] += spec[i] * outputGain;
        }
    };

    if (bit % 2) amplify(loSpectrum[(bit + offset) / 2], residue);
    else         amplify(hiSpectrum[(bit + offset) / 2], residue);
}

- (void) generate_spectrum
{
    loSpectrum.resize(256);
    hiSpectrum.resize(256);

    for (int i = 0; i < 256; i++) 
    {
        loSpectrum[i].resize(samplesPerFrame);
        hiSpectrum[i].resize(samplesPerFrame);

        double hz = 48000.0f * (frequencyStart + 2 * i) / samplesPerFrame;
        double phaseOffset = (M_PI * i) / (8 * payloadFrameSize);

        for (int j = 0; j < samplesPerFrame; j++) 
        {
            float period = 2.0 * M_PI * j / 48000.0;
            loSpectrum[i][j] = std::sin(period * (hz + 48000.0f / samplesPerFrame) + phaseOffset);
            hiSpectrum[i][j] = std::sin(period * hz + phaseOffset);
        }
    }
}
@end