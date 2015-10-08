# ForceSketch
####Demonstration of a Sketching App Using 3D Touch

![screenshot](ForceSketch/ForceSketch.gif)

#####Companion project to this blog post: http://flexmonkey.blogspot.co.uk/2015/10/forcesketch-3d-touch-drawing-app-using.html

Following on from my recent posts on 3D Touch and touch coalescing, combining the two things together in a simple drawing application seemed like an obvious next step. This also gives me the chance to tinker with `CIImageAccumulator` which was newly introduced in iOS 9.

My little demo app, ForceSketch, allows the user to draw on their iPhone 6 screen. Both the line weight and the line colour are linked to the touch pressure. Much like my ChromaTouch demo, the pressure controls the hue, so the very lightest touch is red, turning to green at a third of maximum pressure, to blue at two thirds and back to red at maximum pressure. 

Once the user lifts their finger, two Core Image filters, `CIColorControls` and `CIGaussianBlur` kick in and fade the drawing out.

##Drawing Mechanics of ForceSketch

The drawing code is all called from my view controller's `touchesMoved` method. It's in here that I create a `UIImage` instance based on the coalesced touches and composite that image overthe existing image accumulator. In a production application, I'd probably do the image filtering in a background thread to improve the performance of the user interface but, for this demo, I think this approach is OK.

The opening guard statement ensures I have non-optional constants for the most important items:

```swift
    guard let touch = touches.first,
        event = event,
        coalescedTouches = event.coalescedTouchesForTouch(touch) else
    {
        return
    }
```

The next step is to prepare for creating the image object. To do this, I need to begin an image context and create a reference to the current context:

```swift
    UIGraphicsBeginImageContext(view.frame.size)

    let cgContext = UIGraphicsGetCurrentContext()
```

To ensure I get maximum fidelity of the user's gesture, I loop over the coalesced touches - this gives me all the intermediate touches that may have happened between invocations of `touchesMoved()`.

```swift
    for coalescedTouch in coalescedTouches {
```

Using the force property of each touch, I create constants for the line segments colour and weight. To ensure users of non-3D Touch devices call still use the app, I check `forceTouchCapability` and give those users a fixed weight and colour:

```swift
    let lineWidth = (traitCollection.forceTouchCapability == UIForceTouchCapability.Available) ?
        (coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 20 :
        10
    
    let lineColor = (traitCollection.forceTouchCapability == UIForceTouchCapability.Available) ?
        UIColor(hue: coalescedTouch.force / coalescedTouch.maximumPossibleForce, saturation: 1, brightness: 1, alpha: 1).CGColor :
        UIColor.grayColor().CGColor
```

With these constants I can set the line width and stroke colour in the graphics context:

```swift
    CGContextSetLineWidth(cgContext, lineWidth)
    CGContextSetStrokeColorWithColor(cgContext, lineColor)
```

...and I'm now ready to define the beginning and end of my line segment for this coalesced touch:

```swift
    CGContextMoveToPoint(cgContext,
        previousTouchLocation!.x,
        previousTouchLocation!.y)

    CGContextAddLineToPoint(cgContext,
        coalescedTouch.locationInView(view).x,
        coalescedTouch.locationInView(view).y)
```

The final steps inside the coalesced touches loop is to stroke the path and update `previousTouchLocation`:

```swift
    CGContextStrokePath(cgContext)

    previousTouchLocation = coalescedTouch.locationInView(view)
```

Once all of the strokes have been added to the graphics context, it's one line of code to create a `UIImage` instance and then end the context:

```swift
    let drawnImage = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsEndImageContext()
```

##Displaying the Drawn Lines

To display the newly drawn lines held in drawnImage, I use a `CISourceOverCompositing` filter with `drawnImage` as the foreground image and the image accumulator's current image as the background: 

```swift
    compositeFilter.setValue(CIImage(image: drawnImage),
        forKey: kCIInputImageKey)
        
    compositeFilter.setValue(imageAccumulator.image(),
        forKey: kCIInputBackgroundImageKey)
```

Then take the output of the source over compositor, pass that back into the accumulator and populate my `UIImageView` with the accumulator's image:

```swift
    imageAccumulator.setImage(compositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)

    imageView.image = UIImage(CIImage: imageAccumulator.image())
```
    
##Blurry Fade Out

Once the user lifts their finger, I do a "blurry fade out" of the drawn image. This effect uses two Core Image filters which are defined as constants: 

```swift
    let hsb = CIFilter(name: "CIColorControls",
        withInputParameters: [kCIInputBrightnessKey: 0.05])!
    let gaussianBlur = CIFilter(name: "CIGaussianBlur",
        withInputParameters: [kCIInputRadiusKey: 1])!
```

The first part of the effect is to use a CADisplayLink which will invoke step() with each screen refresh:

```swift
    let displayLink = CADisplayLink(target: self, selector: Selector("step"))
    displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
```

I rely on previousTouchLocation being nil to infer the user has finished their touch. If that's the case, I simply pass the accumulator's current image into the HSB / colour control filter, pass that filter's output into the Gaussian Blur and finally the blur's output back into the accumulator:

```swift
    hsb.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
    gaussianBlur.setValue(hsb.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
    
    imageAccumulator.setImage(gaussianBlur.valueForKey(kCIOutputImageKey) as! CIImage)

    imageView.image = UIImage(CIImage: imageAccumulator.image())
```
    
##Source Code

As always, the source code for this project is available in my GitHub repository here. Enjoy!
