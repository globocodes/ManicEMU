//
//  JITSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Device

class JITSettingView: BaseView {
    
    class JITSettingViewCell: UICollectionViewCell {
        private let jitView: UIView = {
            let view = UIView()
            
            let container = UIView()
            container.backgroundColor = R.Color.BackgroundSecondary
            container.layerCornerRadius = R.Size.CornerRadiusMedium
            view.addSubview(container)
            container.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            let iconView = IconView()
            iconView.contentMode = .center
            iconView.layerCornerRadius = 6
            iconView.image = UIImage(symbol: .boltFill, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
            iconView.backgroundColor = R.Color.Indigo
            container.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.size.equalTo(R.Size.IconSizeLarge)
                make.centerY.equalToSuperview()
            }
            
            let jitLabel = UILabel()
            let jitEnable = LibretroCore.jitAvailable()
            jitLabel.text = jitEnable ? R.string.localizable.jitAllow() : R.string.localizable.jitNotAllow()
            jitLabel.textColor = jitEnable ? R.Color.Green : R.Color.Red
            jitLabel.font = R.Font.Body(emphasis: true)
            container.addSubview(jitLabel)
            jitLabel.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            }
            
            return view
        }()
        
        private lazy var deviceView: UIView = {
            let view = UIView()
            
            let titleContainerView = UIView()
            view.addSubview(titleContainerView)
            titleContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(R.Size.ContentSpaceTiny)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightSmall)
            }
            
            let titleLabel = UILabel()
            titleLabel.text = R.string.localizable.device()
            titleLabel.font = R.Font.Footnote(emphasis: true)
            titleLabel.textColor = R.Color.LabelSecondary
            titleContainerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let storageContainer = UIView()
            storageContainer.backgroundColor = R.Color.BackgroundSecondary
            storageContainer.layerCornerRadius = R.Size.CornerRadiusMedium
            view.addSubview(storageContainer)
            storageContainer.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(titleContainerView.snp.bottom)
                make.height.equalTo(240)
            }
            
            func genItemView(symbol: SFSymbol, title: String, detail: String) -> UIView {
                let containerView = UIView()
                
                let iconView = IconView()
                iconView.contentMode = .center
                iconView.layerCornerRadius = 6
                iconView.image = UIImage(symbol: symbol, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
                iconView.backgroundColor = R.Color.LabelTertiary.forceStyle(.dark)
                containerView.addSubview(iconView)
                iconView.snp.makeConstraints { make in
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                    make.size.equalTo(R.Size.IconSizeLarge)
                    make.centerY.equalToSuperview()
                }
                
                let titleLabel = UILabel()
                titleLabel.text = title
                titleLabel.textColor = R.Color.LabelPrimary
                titleLabel.font = R.Font.Body(emphasis: true)
                containerView.addSubview(titleLabel)
                titleLabel.snp.makeConstraints { make in
                    make.centerY.equalTo(iconView)
                    make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
                }
                
                let detailLabel = UILabel()
                detailLabel.text = detail
                detailLabel.textColor = R.Color.LabelSecondary
                detailLabel.font = R.Font.Caption()
                containerView.addSubview(detailLabel)
                detailLabel.snp.makeConstraints { make in
                    make.centerY.equalTo(iconView)
                    make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                }
                return containerView
            }
            
            //Install Source
            var sourceDetail = ""
            #if SIDE_LOAD
            sourceDetail = "Sideload"
            #else
            sourceDetail = "AppStore"
            #endif
            let sourceView = genItemView(symbol: .appFill, title: R.string.localizable.installSource(), detail: sourceDetail)
            storageContainer.addSubview(sourceView)
            sourceView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            
            //Device
            let deviceView = genItemView(symbol: .iphone, title: R.string.localizable.device(), detail: Device.version().rawValue)
            storageContainer.addSubview(deviceView)
            deviceView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(sourceView.snp.bottom)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            //System
            let v = ProcessInfo.processInfo.operatingSystemVersion
            let systemView = genItemView(symbol: .squareStack3dUpFill, title: R.string.localizable.system(), detail: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
            storageContainer.addSubview(systemView)
            systemView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(deviceView.snp.bottom)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            //Memory
            let memoryBytes = ProcessInfo.processInfo.physicalMemory
            let memoryView = genItemView(symbol: .memorychipFill, title: R.string.localizable.memory(), detail: FileType.humanReadableFileSize(memoryBytes, numeralSystem: 1000, decimalPlaces: 0) ?? "Unknown")
            storageContainer.addSubview(memoryView)
            memoryView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(systemView.snp.bottom)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            return view
        }()
        
#if SIDE_LOAD
        private let enableJITView: UIView = {
            let view = UIView()
            view.enablePressEffect = true
            view.addTapGesture { gesture in
                if UIApplication.shared.canOpenURL(R.URLs.EnableJITUrl) {
                    UIApplication.shared.open(R.URLs.EnableJITUrl)
                } else {
                    UIView.makeToast(message: R.string.localizable.notInstall("StikDebug"))
                }
            }
            
            let container = UIView()
            container.backgroundColor = R.Color.BackgroundSecondary
            container.layerCornerRadius = R.Size.CornerRadiusMedium
            view.addSubview(container)
            container.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            let iconView = IconView()
            iconView.contentMode = .center
            iconView.layerCornerRadius = 6
            iconView.image = UIImage(symbol: .bolt,
                                     font: R.Font.Footnote(emphasis: true),
                                     color: R.Color.LabelPrimary.forceStyle(.dark))
            iconView.backgroundColor = R.Color.BackgroundPrimary.forceStyle(.dark)
            container.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.size.equalTo(R.Size.IconSizeLarge)
                make.centerY.equalToSuperview()
            }
            
            let label = UILabel()
            label.text = LibretroCore.jitAvailable() ?  R.string.localizable.reEnableJIT() : R.string.localizable.enableJIT()
            label.textColor = R.Color.LabelPrimary
            label.font = R.Font.Body(emphasis: true)
            container.addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            }
            
            let chevronIconView = UIImageView(image: UIImage(symbol: .chevronRight, font: R.Font.Caption(emphasis: true), color: R.Color.LabelSecondary))
            chevronIconView.contentMode = .center
            container.addSubview(chevronIconView)
            chevronIconView.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            return view
        }()
        
        private let autoEnableJITView: UIView = {
            let view = UIView()
            
            let container = UIView()
            container.backgroundColor = R.Color.BackgroundSecondary
            container.layerCornerRadius = R.Size.CornerRadiusMedium
            view.addSubview(container)
            container.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            let iconView = IconView()
            iconView.contentMode = .center
            iconView.layerCornerRadius = 6
            iconView.image = UIImage(symbol: .boltFill,
                                     font: R.Font.Footnote(emphasis: true),
                                     color: R.Color.LabelPrimary.forceStyle(.dark))
            iconView.backgroundColor = R.Color.BackgroundPrimary.forceStyle(.dark)
            container.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.size.equalTo(R.Size.IconSizeLarge)
                make.centerY.equalToSuperview()
            }
            
            let switchView = ASSwitchView(.init(state: JITAutoEnabler.isEnabled ? .on : .off))
            switchView.didValueChange = { value in
                JITAutoEnabler.isEnabled = value
            }
            container.addSubview(switchView)
            switchView.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            let label = UILabel()
            label.text = R.string.localizable.autoEnableJIT()
            label.textColor = R.Color.LabelPrimary
            label.font = R.Font.Body(emphasis: true)
            container.addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
                make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-R.Size.ContentSpaceSmall)
            }
            
            return view
        }()
#else
        private let installSideloadView: UIView = {
            let view = UIView()
            view.enablePressEffect = true
            view.addTapGesture { gesture in
                if UIApplication.shared.canOpenURL(R.URLs.InstallSideload) {
                    UIApplication.shared.open(R.URLs.InstallSideload)
                } else {
                    UIApplication.shared.open(R.URLs.SideStore)
                }
            }
            
            let container = UIView()
            container.backgroundColor = R.Color.BackgroundSecondary
            container.layerCornerRadius = R.Size.CornerRadiusMedium
            view.addSubview(container)
            container.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            let iconView = UIImageView()
            iconView.contentMode = .center
            iconView.layerCornerRadius = 6
            iconView.image = R.image.customArrowTriangleheadSwap()?.applySymbolConfig(font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
            iconView.backgroundColor = R.Color.BackgroundPrimary.forceStyle(.dark)
            container.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.size.equalTo(R.Size.IconSizeLarge)
                make.centerY.equalToSuperview()
            }
            
            let label = UILabel()
            label.text = R.string.localizable.installSideloadVersion()
            label.textColor = R.Color.LabelPrimary
            label.font = R.Font.Body(emphasis: true)
            container.addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            }
            
            let chevronIconView = UIImageView(image: UIImage(symbol: .chevronRight, font: R.Font.Caption(emphasis: true), color: R.Color.BackgroundTertiary))
            chevronIconView.contentMode = .center
            container.addSubview(chevronIconView)
            chevronIconView.snp.makeConstraints { make in
                make.centerY.equalTo(iconView)
                make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
            
            return view
        }()
#endif

        private let detailLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 0
#if SIDE_LOAD
            view.text = R.string.localizable.autoEnableJITDesc() + "\n\n" + R.string.localizable.jitDesc()
#else
            view.text = R.string.localizable.jitDesc()
#endif
            view.font = R.Font.Caption()
            view.textColor = R.Color.LabelSecondary
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        
            addSubview(jitView)
            jitView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview().offset(R.Size.ContentSpaceLarge)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            addSubview(deviceView)
            deviceView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(jitView.snp.bottom)
                make.height.equalTo(288)
            }

#if SIDE_LOAD
            addSubview(enableJITView)
            enableJITView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(deviceView.snp.bottom).offset(R.Size.ContentSpaceLarge)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
            
            addSubview(autoEnableJITView)
            autoEnableJITView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(enableJITView.snp.bottom).offset(R.Size.ContentSpaceSmall)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
#else
            addSubview(installSideloadView)
            installSideloadView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(deviceView.snp.bottom).offset(R.Size.ContentSpaceLarge)
                make.height.equalTo(R.Size.ItemHeightLarge)
            }
#endif
            
            addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
#if SIDE_LOAD
                make.top.equalTo(autoEnableJITView.snp.bottom).offset(R.Size.ContentSpaceSmall)
#else
                make.top.equalTo(deviceView.snp.bottom).offset(92)
#endif
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private lazy var navigationView: ASNavigationView = {
        var navigation = ASListPage.Navigation.defaultNavigation(title: "JIT",
                                                                 titleIcon: .symbolImage(R.image.jit_iconSymbols()))
        navigation.enableClose = showClose
        let view = ASNavigationView(navigation)
        view.didTapClose = { [weak self] in
            guard let self = self else { return }
            self.hide()
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: JITSettingViewCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.contentInset = .insets(bottom: UIDevice.isPad ? (R.Size.ContentInsetBottom + R.Size.HomeTabBarSize.height + R.Size.ContentSpaceLarge) : R.Size.ContentInsetBottom)
        return view
    }()
    
    private let showClose: Bool

    required init?(parameters: Any...) {
        self.showClose = parameters.compactMap({ $0 as? Bool }).first ?? true
        super.init(frame: .zero)
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            if showClose {
                make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            } else {
                make.top.equalToSuperview().offset(R.Size.ContentInsetTop)
            }
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    convenience init(showClose: Bool = true) {
        self.init(parameters: showClose)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            
            //group布局
#if SIDE_LOAD
            //One more row and its description than the App Store page
            let groupHeight: CGFloat = 720
#else
            let groupHeight: CGFloat = 600
#endif
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(groupHeight)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: R.Size.ContentSpaceSmall, trailing: 0)
            
            return section
        }
        return layout
    }
}

extension JITSettingView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: JITSettingViewCell.self, for: indexPath)
        return cell
    }
}

extension JITSettingView: UICollectionViewDelegate {
    
}

extension JITSettingView: ShowableView {
    
}
