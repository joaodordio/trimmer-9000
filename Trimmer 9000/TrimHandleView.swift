//
//  TrimHandleView.swift
//  Trimmer 9000
//
//  Created by Joao Dordio on 26/09/2022.
//

import UIKit

class TrimHandleView: UIView {
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    var orientation: TrimmerOrientation = .left
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit(orientation: .left)
    }
    
    init(orientation: TrimmerOrientation) {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 40, height: 50)))
        commonInit(orientation: orientation)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit(orientation: .left)
    }
    
    func commonInit(orientation: TrimmerOrientation) {
        Bundle.main.loadNibNamed("TrimHandleView", owner: self)
        addSubview(contentView)
        contentView.bounds = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        switch orientation {
        case .left:
            imageView.image = UIImage(systemName: "arrow.right.to.line")
        case .right:
            imageView.image = UIImage(systemName: "arrow.left.to.line")
        }
    }
}

enum TrimmerOrientation {
    case left, right
}
