# chronos

*Proof of concept framework for synchronizing iOS events with high-frequency tones*

## Building and integrating the Chronos framework

```
# Ensure that you've cloned the submodules
git submodule update --init --recursive

# Build the framework
cd chronos/
./build_framework.sh
```

The framework will then be available under `../build/Release-iphoneos/`. 

You may then drag and drop this into the project you wish to integrate the framework into. Make sure to embed and sign the framework.

---

## Using the Chronos framework

The Chronos framework exposes exactly one public class called `Chronos`, which should exist as a singleton object.

After creating an instance and setting an appropriate delegate, you may call `start`. This will request access to the microphone, and if granted, will start analyzing samples received via the standard audio capture input (e.g. iPhone microphone). To stop the microphone you may call `stop`. To reset the internal state without stopping, call `reset`.

A convenience method `requestMicrophonePermission` has been exposed so that you can ask for permission without automatically starting.

You may also set the `enableDebug` flag on the `Chronos` object to obtain various information about the current state.

Any delegate assigned to an instance of a `Chronos` object is required to implement three delegate methods: `hasObservedSyncTransition(_ hasSynchronized: Bool)`, `hasObservedIdentifier(_ identifier: Int)`, and `hasObservedTimestamp(_ timestamp: Double)`.

One other important note is that your project's Info.plist should include an NSMicrophoneUsageDescription. Your project will fail to run without this.

---

## Example usage

```swift
import UIKit
import Chronos

class ViewController: UIViewController
{
    private var chronos : Chronos!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        chronos = Chronos()
        chronos.delegate = self
        chronos.enableDebug = true
        
        chronos.requestMicrophonePermission { granted in
            if granted 
            {
                self.chronos.start()
            }
        }
    }

    func hasObservedSyncTransition(_ hasSynchronized: Bool)
    {
        // Are we currently synchronized?
    }

    func hasObservedIdentifier(_ identifier: Int)
    {
        // A unique identifier for a witnessed encoded audio track.
    }

    func hasObservedTimestamp(_ timestamp: Double)
    {
        // Real time updates of the internal timer provided as long as
        // we remain in the synchronized state.
    }
}
```

## Wav generation

Generates .wav files which encode the information you intend to transmit, e.g. a timestamp.

To compile, run:

```
cd pcm
g++ -std=c++17 -x objective-c++ -framework Foundation main.mm Modulator.mm -o encoder
```

Then encode a payload (identifier, timestamp) as a packed int where each part occupies the first and second 32-bits, respectively. Then convert this payload to a wav file by running:

```
./encoder <payload>
```

You will then need to overlay these onto your media's audio track, e.g. using [ffmpeg](https://ffmpeg.org/), at their respective timestamps. 