//
//  ViewController.swift
//  ViewFliperTest
//
//  Created by Andreas Neusüß on 20.02.16.
//  Copyright © 2016 Anerma. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    enum DirectionOfPan {
        case upwards, downwards
    }
    enum StateOfView {
        case finished, initial
    }
    
    /// Holds the point on which the last progress was calculated. Used to determin a delta-progress for every sample of gesture.
    fileprivate var pointOfLastCalculatedProgress : CGPoint = .zero
    
    /// Gesture recognizer that tracks panning.
    lazy fileprivate var gestureRecognizer : UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(target: self, action: #selector(ViewController.gestureRecognizerDidFire(_:)))
    }()
    
    /// This value holds the global progress of the gesture. For every sample of the gesture, a small delta-progress is calculated and than added to this varaible. While the first view is interactive, cumulativeProgress is between 0 and 1. If the user interacts with the second view, it goes from 1 to 2.
    fileprivate var cumulativeProgress: Float = 0

    /// Array of views that the user can interact with.
    fileprivate var interactiveViews = [UIView]()
    
    /// Array of images that the interactiveViews should display. It determines the number of views that will be created and displayed.
    fileprivate let images = [UIImage(named: "0"), UIImage(named: "1"), UIImage(named: "2"), UIImage(named: "3"), UIImage(named: "4"), UIImage(named: "5"), UIImage(named: "6"), UIImage(named: "7"), UIImage(named: "8"), UIImage(named: "9")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        prepareinteractiveViews()
        view.addGestureRecognizer(gestureRecognizer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /**
     Fills the array interactiveViews with Views that display images form images.
     */
    fileprivate func prepareinteractiveViews() {
        for (index, image) in images.enumerated() {
            
            
            let newView = UIImageView(frame: frameForViewAtIndex(index))
            
            newView.image = image
            
            newView.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
            newView.layer.position.y += newView.bounds.size.height/2
            
            
            //z position to order the views in z direction. Adding additional padding (based on frame height of newView due to avoid collision between views during an spring animation.
            newView.layer.zPosition = CGFloat(images.count-index) + CGFloat(2.5 * newView.frame.size.height)
            
            
            interactiveViews.append(newView)
            
            self.view.addSubview(newView)

        }
    }
    
    /**
     Calculates the frame for a view at a given index.
     
     - parameter index: Index of the view whose rect is asked.
     
     - returns: CGRect of the view at index.
     */
    fileprivate func frameForViewAtIndex(_ index: Int) -> CGRect {
        let floatIndex = CGFloat(index)
        
        
        let sizeOfNewView = CGSize(width: 300 - floatIndex * 10, height: 200 - floatIndex * 5)
        
        let originOfNewView = CGPoint(x: view.center.x - sizeOfNewView.width / 2.0, y: view.center.y - sizeOfNewView.height / 2.0 - floatIndex * 10)
        
        return CGRect(origin: originOfNewView, size: sizeOfNewView)
        
    }

    @IBAction func startButtonPressed(_ sender: AnyObject) {
        
        let viewToAnimate = viewForIndex(indexOfInteractiveViewBasedOnCumulativeProgress(cumulativeProgress))
        animateView(viewToAnimate, toState: .finished, basedOnInitialVelocity: 0)
        
        cumulativeProgress += 1
    }
    
    /**
     Gesture recognizer handling.
     Controls flow of interaction
     
     - parameter gestureRecognizer: A UIPanGestureRecognizer.
     */
    func gestureRecognizerDidFire(_ gestureRecognizer: UIPanGestureRecognizer) {
        let locationOfTouch = gestureRecognizer.location(in: gestureRecognizer.view!)
        let direction : DirectionOfPan = gestureRecognizer.velocity(in: gestureRecognizer.view!).y < 0 ? .upwards : .downwards
        
        switch gestureRecognizer.state {
        case .began:
            pointOfLastCalculatedProgress = locationOfTouch
        case .ended:
            let velocityOfTouch = gestureRecognizer.velocity(in: gestureRecognizer.view!).y
            let velocityOfSpring = initialVelocityOfSpringAnimationBasedOnGestureRecognizerVelocity(velocityOfTouch, distance: 100)
            let indexOfViewToAnimate = indexOfInteractiveViewBasedOnCumulativeProgress(cumulativeProgress)
            let viewToAnimate = viewForIndex(indexOfViewToAnimate)
            
            //True if we have reached the last view. We do not want to flip it down and therefore never let the transaction reach the finished state
            let haveReachedLastView = indexOfViewToAnimate == interactiveViews.count-1
            
            
            //cancel or finish...
            if shouldFinishGestureBasedOnProgress(progressForViewWithIndex(indexOfInteractiveViewBasedOnCumulativeProgress(cumulativeProgress), fromcumulativeProgress: cumulativeProgress), directionOfGesture: direction) || haveReachedLastView {
                
               //pulling upwards
               //cancel with animation
                
                animateView(viewToAnimate, toState: .initial, basedOnInitialVelocity: velocityOfSpring)
                animateNextViewIntoPositionBasedOnInteractiveViewState(.initial)
                
                cumulativeProgress -= 1
                cumulativeProgress = ceil(cumulativeProgress)
            }
            else {
                //pulling downwards
                
                
                //finish with animation
                animateView(viewToAnimate, toState: .finished, basedOnInitialVelocity: velocityOfSpring)
                animateNextViewIntoPositionBasedOnInteractiveViewState(.finished)
                

                cumulativeProgress += 1
                cumulativeProgress = floor(cumulativeProgress)
            }
            
            
        case .changed:
            let travelledDistance = pointOfLastCalculatedProgress.distanceToPoint(locationOfTouch)
            let progressOfInteraction = progressForTravelledDistance(travelledDistance)
            
            //check lower bound of cumulativeProgress. Must not be smaller than 0.
            if cumulativeProgress + progressOfInteraction >= 0 {
                
                if cumulativeProgress + progressOfInteraction <= Float(interactiveViews.count) {
                    
                    
                    cumulativeProgress += progressOfInteraction
                }
            }
            else {
                cumulativeProgress = 0
            }
            
            let indexOfInteractiveView = indexOfInteractiveViewBasedOnCumulativeProgress(cumulativeProgress)
            let interactiveView = viewForIndex(indexOfInteractiveView)
            
            let progressOfInteractiveView = progressForViewWithIndex(indexOfInteractiveView, fromcumulativeProgress: cumulativeProgress)
            
            updateInteractiveView(interactiveView, basedOnPercentage: progressOfInteractiveView)
            
            pointOfLastCalculatedProgress = locationOfTouch
            
        default:
            ()
        }
    }
    
    /**
     Calculates the progress of interaction based on the distance that it has traversed.
     
     - parameter distance: Distance that the gesture has traversed.
     
     - returns: Progress corresponding to to travelled distance. Between -1 and 1
     */
    fileprivate func progressForTravelledDistance(_ distance : Float) -> Float {
        let maximum : Float = 200.0
        
        let relativeProgress = distance / maximum
        let normalizedProgress = min(1, max(-1, relativeProgress))

//        print("progress: \(normalizedProgress)")
        return normalizedProgress


    }
    /**
     Responsible for updating the visual appearence of a given view based on a percentage.
     Used to perform the changes to a view reguaring the progress.
     
     - parameter animatedView: The view to update. It will perform a 'fall' movement based on the progress.
     - parameter progress:     Progress of the gesture. Between 0 and 1.
     */
    fileprivate func updateInteractiveView(_ animatedView: UIView, basedOnPercentage progress: Float) {

        guard progress >= 0 && progress <= 1 else {
            print("PROGRESS MUST BE BETWEEN 0 AND 1")
            animatedView.layer.transform = CATransform3DIdentity
            return
        }
        

//        animatedView.layer.zPosition = CGFloat(colors.count)//view.frame.size.height / 1.7
        var perspective = CATransform3DIdentity
        perspective.m34 = -1/300
        let rotation = CATransform3DRotate(perspective, CGFloat(Float(-M_PI) * progress), 1, 0, 0)

        animatedView.layer.transform = rotation
        animatedView.alpha = CGFloat(1 - progress)
        

    }

    /**
     Animate a given view to a given state. Used to animate the completion or cancellation after a gesture finished.
     
     - parameter view:     The view that shall be animated.
     - parameter state:    The state to which the view shall transition to. -> StateOfView
     - parameter velocity: Initial velocity of the spring gesture. It has to be calculated based on the gesture velocity at the point where the user lets go.
     */
    fileprivate func animateView(_ view: UIView, toState state: StateOfView, basedOnInitialVelocity velocity: CGFloat) {

        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: velocity, options: [.beginFromCurrentState, .curveLinear], animations: { () -> Void in
            
            
            self.updateInteractiveView(view, basedOnPercentage: (state == .initial) ? 0 : 1)
            
            }) { (_) -> Void in
                
        }

    }
    /**
     Animated the next view into place. The next view is the one that is not interactive but the one after.
     
     - parameter state: State in which the currently interactive view is heading to. Eg. if it is finishing, the next view will snap into place but if it cancels, the next view has to snap back to its original position.
     */
    fileprivate func animateNextViewIntoPositionBasedOnInteractiveViewState(_ state: StateOfView) {
        let indexOfNextView = indexOfInteractiveViewBasedOnCumulativeProgress(cumulativeProgress) + 1
        if indexOfNextView == interactiveViews.count {
            return
        }
        let viewToAnimate = viewForIndex(indexOfNextView)
        
        let newFrameForView : CGRect
        if state == .finished {
            newFrameForView = frameForViewAtIndex(0)
        }
        else {
            newFrameForView = frameForViewAtIndex(indexOfNextView)
        }
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: { () -> Void in
            
            viewToAnimate.frame = newFrameForView
            
            }) { (_) -> Void in
                
        }
        
    }


    /**
     Returns a view based on an index from the interactiveViews array. Save to ask about view outside of arrays bounds (like -1 or interactiveViews.count + 1)
     
     - parameter index: Index of the desired view.
     
     - returns: The view from interactiveViews array based on a given index. First view, if index < 0 and last view, if index > interactiveViews.count-1.
     */
    fileprivate func viewForIndex(_ index: Int) -> UIView {
        if index < 0 {
            return interactiveViews.first!
        }
        if index > interactiveViews.count - 1 {
            return interactiveViews.last!
        }
        return interactiveViews[index]
    }

    /**
     Calculates index of the interactive view based on the global CumulativeProgress value.
     
     - parameter cumulativeProgress: Entire process of interaction
     
     - returns: Index for the interactive view.
     */
    fileprivate func indexOfInteractiveViewBasedOnCumulativeProgress(_ cumulativeProgress: Float) -> Int {
        var index = Int(floor(cumulativeProgress))
//        print("index '\(index)' based on progress \(cumulativeProgress)")
        if index < 0 {
            index = 0
        }

        return index
    }
    
    /**
     Calculates the individual progress of the interactive view (at index) based on the entire cumulativeProgress.
     
     - parameter index:              Index of the view whose progress should be calculated
     - parameter cumulativeProgress: CumulativeProgress of the entire interaction.
     
     - returns: A progress value between 0 and 1 for the individual view at given index.
     */
    fileprivate func progressForViewWithIndex(_ index: Int, fromcumulativeProgress cumulativeProgress: Float) -> Float {
        let progress = cumulativeProgress - Float(index)
//        print("progress for view is \(progress), based on index\(index) and cumulativeProgress \(cumulativeProgress)")
        return progress
    }
    
    /**
     Calculates the value passed into initialVelocity of UIView spring animation because it is NOT THE SAME as the velocity that the gesture recognizer recorded from the users gesture.
     Use this value to ensure a seemless continuation of an animation after the user has let go the view after a pan.
     
     - parameter velocityOfGR: Velocity that the GestureRecognizer has recorded
     - parameter distance:     Distance that the animated view should traverse.
     
     - returns: Velocity of UIView spring animation to match the users gesture velocity.
     */
    fileprivate func initialVelocityOfSpringAnimationBasedOnGestureRecognizerVelocity(_ velocityOfGR: CGFloat, distance: CGFloat) -> CGFloat {
        
        return fabs(velocityOfGR / distance)
    }
    
    fileprivate func shouldFinishGestureBasedOnProgress(_ progress: Float, directionOfGesture: DirectionOfPan) -> Bool {
        
        if directionOfGesture == .upwards {
            return progress < 0.7
        }
        else {
            return progress < 0.4
        }
    }
}


extension CGPoint {
    /**
     Distance between a given point and self in Y direction.
     
     - parameter point: The point of which to calculate a distance from.
     
     - returns: Distance to this point in Y direction.
     */
    func distanceToPoint(_ point: CGPoint) -> Float{
//        let dxAbs = (self.x - point.x)
        let dy = (point.y - self.y)
        
        return Float(dy)//sqrt(Float(dxAbs * dxAbs + dyAbs * dyAbs))
    }
}
