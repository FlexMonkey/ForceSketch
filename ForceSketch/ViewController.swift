//
//  ViewController.swift
//  ForceSketch
//
//  Created by SIMON_NON_ADMIN on 07/10/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{
    let imageView = UIImageView()
    
    let hsb = CIFilter(name: "CIColorControls", withInputParameters: [kCIInputBrightnessKey: 0.05])!
    let gaussianBlur = CIFilter(name: "CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: 1])!
    let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
    var imageAccumulator: CIImageAccumulator!
    
    var previousTouchLocation: CGPoint?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        imageAccumulator = CIImageAccumulator(extent: view.frame, format: kCIFormatARGB8)
        
        view.addSubview(imageView)
        
        let displayLink = CADisplayLink(target: self, selector: Selector("step"))
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    func step()
    {
        if previousTouchLocation == nil
        {
            hsb.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
            gaussianBlur.setValue(hsb.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
            
            imageAccumulator.setImage(gaussianBlur.valueForKey(kCIOutputImageKey) as! CIImage)
            
            imageView.image = UIImage(CIImage: imageAccumulator.image())
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        previousTouchLocation = touches.first?.locationInView(view)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first,
            event = event,
            coalescedTouches = event.coalescedTouchesForTouch(touch) else
        {
            return
        }

        let imageSize = view.frame.size
        
        UIGraphicsBeginImageContext(imageSize)
        
        let cgContext = UIGraphicsGetCurrentContext()

        CGContextSetLineCap(cgContext, CGLineCap.Round)

        for coalescedTouch in coalescedTouches
        {
            let lineWidth = (traitCollection.forceTouchCapability == UIForceTouchCapability.Available) ?
                (coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 20 :
                10
            
            let lineColor = (traitCollection.forceTouchCapability == UIForceTouchCapability.Available) ?
                UIColor(hue: coalescedTouch.force / coalescedTouch.maximumPossibleForce, saturation: 1, brightness: 1, alpha: 1).CGColor :
                UIColor.grayColor().CGColor
            
            CGContextSetLineWidth(cgContext, lineWidth)
            CGContextSetStrokeColorWithColor(cgContext, lineColor)
            
            CGContextMoveToPoint(cgContext,
                previousTouchLocation!.x,
                previousTouchLocation!.y)
      
            CGContextAddLineToPoint(cgContext,
                coalescedTouch.locationInView(view).x,
                coalescedTouch.locationInView(view).y)
            
            previousTouchLocation = coalescedTouch.locationInView(view)
            
            CGContextStrokePath(cgContext)
        }
       
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
  
        compositeFilter.setValue(CIImage(image: drawnImage),
            forKey: kCIInputImageKey)
        compositeFilter.setValue(imageAccumulator.image(),
            forKey: kCIInputBackgroundImageKey)
        
        imageAccumulator.setImage(compositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        
        imageView.image = UIImage(CIImage: imageAccumulator.image())
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        previousTouchLocation = nil
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = view.frame
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask
    {
        return UIInterfaceOrientationMask.Portrait
    }


}

