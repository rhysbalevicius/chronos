//
//  main.mm
//  lipsync
//
//  Created by Rhys Balevicius.
//

#import <Foundation/Foundation.h>
#import "include/Modulator.h"
#import "include/AudioFile/AudioFile.h"

int main(int argc, const char* argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (argc <= 1) {
        printf("Hint: pass in a string as the first argument\n");
        return -1;
    }

    Modulator *modulator = [[Modulator alloc] init];

    int messageSize = strlen(argv[1]);
    std::vector<float> pcm_buffer;
    std::vector<uint8_t> message (256);
    std::copy(argv[1], argv[1] + messageSize, message.begin());

    // Generate the encoded waveform
    [modulator generate_pcm_buffer: pcm_buffer
                           message: message
                              size: messageSize];

    // Initialize the audio file object
    AudioFile<float> a;
    a.setNumChannels (1);
    a.setNumSamplesPerChannel (48000);
    a.setSampleRate (48000);
    a.setBitDepth (16);

    // Write audio to disk
    for (int i = 0; i < 48000; i++) a.samples[0][i] = pcm_buffer[i];
    a.save ("output.wav", AudioFileFormat::Wave);

    [modulator release];
    [pool release];

    return 0;
}