//
//  ViewController.swift
//  ForceSketch
//
//  Created by SIMON_NON_ADMIN on 07/10/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let imageView = UIImageView()
    let hsb = CIFilter(name: "CIColorControls",
                       parameters: [kCIInputBrightnessKey: 0.05])!
    let gaussianBlur = CIFilter(name: "CIGaussianBlur",
                                parameters: [kCIInputRadiusKey: 1])!
    let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
    var imageAccumulator: CIImageAccumulator!
    var previousTouchLocation: CGPoint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageAccumulator = CIImageAccumulator(extent: view.frame, format: CIFormat.ARGB8)
        
        view.addSubview(imageView)
        
        let displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }
    
    @objc func step() {
        if previousTouchLocation == nil
        {
            hsb.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
            gaussianBlur.setValue(hsb.value(forKey: kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
            
            imageAccumulator.setImage(gaussianBlur.value(forKey: kCIOutputImageKey) as! CIImage)
            
            imageView.image = UIImage(ciImage: imageAccumulator.image())
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        previousTouchLocation = touches.first?.location(in: view)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
            let event = event,
            let coalescedTouches = event.coalescedTouches(for: touch) else
        {
            return
        }

        UIGraphicsBeginImageContext(view.frame.size)
        
        let cgContext = UIGraphicsGetCurrentContext()!

        cgContext.setLineCap(CGLineCap.round)

        for coalescedTouch in coalescedTouches
        {
            let lineWidth = coalescedTouch.force != 0 ?
                (coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 20 :
                10
            
            let lineColor = coalescedTouch.force != 0  ?
                UIColor(hue: coalescedTouch.force / coalescedTouch.maximumPossibleForce, saturation: 1, brightness: 1, alpha: 1).cgColor :
                UIColor.gray.cgColor
            
            cgContext.setLineWidth(lineWidth)
            cgContext.setStrokeColor(lineColor)
            cgContext.move(to: CGPoint(x: previousTouchLocation!.x, y: previousTouchLocation!.y))
            cgContext.addLine(to: CGPoint(x: coalescedTouch.location(in: view).x, y: coalescedTouch.location(in: view).y))

            cgContext.strokePath()
            
            previousTouchLocation = coalescedTouch.location(in: view)
        }
       
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()!

        UIGraphicsEndImageContext()
  
        compositeFilter.setValue(CIImage(image: drawnImage),
            forKey: kCIInputImageKey)
        compositeFilter.setValue(imageAccumulator.image(),
            forKey: kCIInputBackgroundImageKey)
        
        imageAccumulator.setImage(compositeFilter.value(forKey: kCIOutputImageKey) as! CIImage)
        
        imageView.image = UIImage(ciImage: imageAccumulator.image())
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        previousTouchLocation = nil
    }
    
    override func viewDidLayoutSubviews() {
        imageView.frame = view.frame
    }
}

