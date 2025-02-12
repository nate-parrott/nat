//
//  CGAdditions.swift
//  ARRenderer
//
//  Created by Nate Parrott on 1/11/20.
//  Copyright © 2020 Nate Parrott. All rights reserved.
//

import AppKit

//extension CGPoint {
//  func angleTo(_ point: CGPoint) -> CGFloat {
//    return atan2(point.y - y, point.x - x)
//  }
//  func scaled(_ k: CGFloat, about: CGPoint) -> CGPoint {
//    return (self - about) * k + about
//  }
//  func rotated(_ k: CGFloat, about: CGPoint) -> CGPoint {
//    return CGPoint(angle: (self - about).angle + k) * (self - about).length() + about
//  }
//  var nearbyTouchPointsToHitTest: [CGPoint] {
//    var points = [self]
//    for dist: CGFloat in [5, 15] {
//      for angle: CGFloat in [0, 60, 120, 180, 240, 300] {
//        let rads = angle * CGFloat.pi / 180
//        points.append(self + CGPoint(angle: rads) * dist)
//      }
//    }
//    return points
//  }
//    func angleTo(_ point: CGPoint, fallback: CGFloat) -> CGFloat {
//        if distanceTo(point) == 0 {
//            return fallback
//        }
//        return angleTo(point)
//    }
//    func moved(dist: CGFloat, angle: CGFloat) -> CGPoint {
//        let dx = cos(angle) * dist
//        let dy = sin(angle) * dist
//        return CGPoint(x: x + dx, y: y + dy)
//    }
//}
//
//extension CGRect {
//    var midPoint: CGPoint { CGPoint(x: midX, y: midY) }
//}
//
//func /(lhs: CGPoint, rhs: CGSize) -> CGPoint {
//    return CGPoint(x: lhs.x / rhs.width, y: lhs.y / rhs.height)
//}
//
//extension CGRect {
//    var roundedToPixels: CGRect {
//        let density = UIScreen.main.scale
//        return CGRect(x: round(minX * density) / density, y: round(minY * density) / density, width: round(width * density) / density, height: round(height * density) / density)
//    }
//}
//
//func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
//    CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
//}

extension CGSize {
    var maxDimension: CGFloat {
        max(width, height)
    }
}

func remap(x: CGFloat, domainStart: CGFloat, domainEnd: CGFloat, rangeStart: CGFloat, rangeEnd: CGFloat) -> CGFloat {
    if domainStart == domainEnd {
        return rangeStart
    }
    let t = (x - domainStart) / (domainEnd - domainStart)
    return rangeStart + (rangeEnd - rangeStart) * t
}

func remapClamped(x: CGFloat, domainStart: CGFloat, domainEnd: CGFloat, rangeStart: CGFloat, rangeEnd: CGFloat) -> CGFloat {
    if domainStart == domainEnd {
        return rangeStart
    }
    let t = (x - domainStart) / (domainEnd - domainStart)
    let t2 = max(0, min(1, t))
    return rangeStart + (rangeEnd - rangeStart) * t2
}

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    var center: CGPoint {
        .init(x: midX, y: midY)
    }
}
