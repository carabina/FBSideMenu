//
//  FBSideMenuViewController.swift
//  FBSideMenu
//
//  Created by 李翔 on 11/11/16.
//  Copyright © 2016 Xiang Li. All rights reserved.
//

import UIKit

public enum FBSideMenuRevealingType {
    case none
    case left
    case right
}

open class FBSideMenuViewController: UIViewController {

    open var leftSideViewController : UIViewController? {
        willSet(newLeftSideViewController) {
            if newLeftSideViewController == leftSideViewController {
                return;
            }

            leftSideViewController?.willMove(toParentViewController: nil)
            leftSideViewController?.view.removeFromSuperview()
            leftSideViewController?.removeFromParentViewController()

            guard let newLeftSideViewController = newLeftSideViewController else {
                return;
            }

            newLeftSideViewController.willMove(toParentViewController: self)
            newLeftSideViewController.view.bounds = view.bounds
            view.addSubview(newLeftSideViewController.view)
            view.bringSubview(toFront: mainViewController.view)
            self.addChildViewController(newLeftSideViewController)
            newLeftSideViewController.didMove(toParentViewController: self)

            let tap = UIPanGestureRecognizer(target: self, action: #selector(mainViewDragged(panGestureRecognizer:)))
            newLeftSideViewController.view.addGestureRecognizer(tap)
        }
    }

    open var mainViewController : UIViewController {
        willSet(newMainViewController) {
            if newMainViewController == mainViewController {
                return;
            }

            mainViewController.willMove(toParentViewController: nil)
            mainViewController.view.removeFromSuperview()
            mainViewController.removeFromParentViewController()
            mainViewController.didMove(toParentViewController: nil)

            self.initMainViewController(newMainViewController)
        }
    }

    open var revealingState: FBSideMenuRevealingType = .none
    open var leftRevealingWidth: CGFloat = 0
    open var leftRevealingThreshold: CGFloat = 0
    public var revealAnimationVelocity: CGFloat = 250    // unit should be (CGFloat per Second)
    public var enableMainViewAlphaTransition: Bool = true

    init(mainViewController: UIViewController, leftSideViewController: UIViewController?) {
        self.mainViewController = mainViewController
        super.init(nibName: nil, bundle: nil)
        self.initMainViewController(mainViewController)
        defer {
            self.leftSideViewController = leftSideViewController
        }
    }

    // MARK: NSCoding
    required public init?(coder aDecoder: NSCoder) {
        self.mainViewController = aDecoder.decodeObject(forKey: "mainViewController") as! UIViewController
        super.init(coder: aDecoder)
        self.initMainViewController(mainViewController)
        defer {
            self.leftSideViewController = aDecoder.decodeObject(forKey: "leftSideViewController") as! UIViewController?
        }
    }

    open override func encode(with aCoder: NSCoder) {
        aCoder.encode(leftSideViewController)
        aCoder.encode(mainViewController)
        super.encode(with: aCoder)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        if leftRevealingWidth == 0 {
            leftRevealingWidth = view.frame.width / 3
        }
        if leftRevealingThreshold == 0 {
            leftRevealingThreshold = view.frame.width / 6
        }
    }

    // MARK: Private Method -
    private func initMainViewController(_ mainViewController: UIViewController) {
        mainViewController.willMove(toParentViewController: self)
        self.addChildViewController(mainViewController)
        mainViewController.view.bounds = self.view.bounds
        view.addSubview(mainViewController.view)
        mainViewController.didMove(toParentViewController: self)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(mainViewDragged(panGestureRecognizer:)))
        mainViewController.view.addGestureRecognizer(panGestureRecognizer)

        let tapGesutreRecognizer = UITapGestureRecognizer(target: self, action: #selector(mainViewTapped(tapGestureRecognizer:)))
        mainViewController.view.addGestureRecognizer(tapGesutreRecognizer)
    }

    @objc private func mainViewDragged(panGestureRecognizer: UIGestureRecognizer) {
        guard let panGestureRecognizer = panGestureRecognizer as? UIPanGestureRecognizer else {
            return;
        }
        guard panGestureRecognizer.view == mainViewController.view else {
            return;
        }

        let targetView = panGestureRecognizer.view!
        let translation = panGestureRecognizer.translation(in: targetView)
        let originalCenter = targetView.center
        let newCenterX = min(view.frame.width / 2 + leftRevealingWidth, originalCenter.x + translation.x)
        self.toggleUnderneathView()
        targetView.center = CGPoint(x: newCenterX, y: originalCenter.y)
        panGestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: targetView)

        if panGestureRecognizer.state == .ended ||
           panGestureRecognizer.state == .cancelled {
            if targetView.frame.minX > leftRevealingThreshold {
                self.revealLeft(aniamted: true)
            } else {
                self.revealNothing(animated: true)
            }
        } else {
            self.updateMainViewAlpha()
        }
    }

    @objc private func mainViewTapped(tapGestureRecognizer: UIGestureRecognizer) {
        guard let tapGestureRecognizer = tapGestureRecognizer as? UITapGestureRecognizer else {
            return;
        }
        guard tapGestureRecognizer.view == mainViewController.view else {
            return;
        }

        if revealingState == .none {
            return;
        }

        revealNothing(animated: true)
    }

    private func toggleUnderneathView() {
        if mainViewController.view.frame.minX < 0 {
            leftSideViewController?.view.isHidden = true
        } else {
            leftSideViewController?.view.isHidden = false
        }
    }

    private func updateMainViewAlpha() {
        mainViewController.view.alpha = calculatedMainViewAlpha(minX: mainViewController.view.frame.minX)
    }

    private func calculatedMainViewAlpha(minX: CGFloat) -> CGFloat {
        if !enableMainViewAlphaTransition {
            return 1
        }
        return 1 - abs(mainViewController.view.frame.minX) / view.frame.width
    }

    private func revealNothing(animated: Bool) {
        let animationDuration = TimeInterval(abs(mainViewController.view.frame.minX) / revealAnimationVelocity)
        UIView.animate(withDuration: animationDuration, animations: {
            self.mainViewController.view.frame = self.view.frame
            self.mainViewController.view.alpha = self.calculatedMainViewAlpha(minX: 0)
        }, completion: { (finished) in
            self.leftSideViewController?.view.isHidden = true
        })
        revealingState = .none
    }

    private func revealLeft(aniamted: Bool) {
        leftSideViewController?.view.isHidden = false
        let leftPoint = CGPoint(x: leftRevealingWidth, y: 0)
        let animationDuration = TimeInterval(abs(mainViewController.view.frame.minX - leftRevealingWidth) / revealAnimationVelocity)
        UIView.animate(withDuration: animationDuration, animations: {
            self.mainViewController.view.frame = CGRect(origin: leftPoint, size: self.view.frame.size)
            self.mainViewController.view.alpha = self.calculatedMainViewAlpha(minX: self.leftRevealingWidth)
        })
        revealingState = .left
    }

}
