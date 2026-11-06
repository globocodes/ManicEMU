//
//  AirPlayViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later



class AirPlayViewController: UIViewController {
    private var gameContainerView = UIView()
    
    var gameView: GameView?
    
    weak var libretroView: UIView?

    /// Manic MP: the height the game view was scaled from, so the scale can follow the window.
    private var scaledGameViewHeight: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let icon = UIImageView(image: R.image.file_icon())
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(200)
        }
        
        let label = UILabel(text: R.string.localizable.airPlayDesc(), style: .largeTitle)
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(icon.snp.bottom).offset(30)
        }
        
        view.addSubview(gameContainerView)
        gameContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func addLibretroView(_ gameView: UIView, dimensions: CGSize, scalingType: GameOption.AirPlayScaling) -> CGSize {
        var dimensions = dimensions
        switch scalingType {
        case .square, .standard, .widescreen:
            if dimensions.width >= dimensions.height {
                dimensions = CGSize(width: dimensions.maxDimension, height: dimensions.maxDimension*scalingType.ratio.height/scalingType.ratio.width)
            } else {
                dimensions = CGSize(width: dimensions.maxDimension*scalingType.ratio.width/scalingType.ratio.height, height: dimensions.maxDimension)
            }
        case .full:
            if let externalWindow = ExternalSceneDelegate.externalWindow {
                if dimensions.width >= dimensions.height {
                    dimensions = CGSize(width: dimensions.maxDimension, height: dimensions.maxDimension*externalWindow.height/externalWindow.width)
                } else {
                    dimensions = CGSize(width: dimensions.maxDimension*externalWindow.width/externalWindow.height, height: dimensions.maxDimension)
                }
            }
        default:
            break
        }
        
        gameContainerView.transform = .identity
        gameContainerView.subviews.forEach { $0.removeFromSuperview() }
        let gameViewHeight = dimensions.height
        scaledGameViewHeight = gameViewHeight
        
        gameContainerView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(dimensions)
        }
        
        self.libretroView = gameView
        gameContainerView.addSubview(gameView)
        gameView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let windowSize = ExternalSceneDelegate.externalWindow {
            let scale = windowSize.height/gameViewHeight
            gameContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        } else {
            DispatchQueue.main.asyncAfter(delay: 1) {
                let scale = self.view.frame.size.height/gameViewHeight
                self.gameContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
        
        return dimensions
    }

    /// Manic MP: the external screen can change mode after the game view was
    /// placed (the "AirPlay 720p Stream" setting, or the TV renegotiating). The
    /// scale to the window height is recomputed when the window's size changes,
    /// and the fork's Vulkan context resizes its swapchain to match.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard scaledGameViewHeight > 0,
              let libretroView, libretroView.superview === gameContainerView,
              view.bounds.height > 0 else { return }
        let scale = view.bounds.height / scaledGameViewHeight
        if abs(gameContainerView.transform.a - scale) > 0.001 {
            gameContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
