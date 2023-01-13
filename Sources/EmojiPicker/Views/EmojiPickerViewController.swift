// The MIT License (MIT)
// Copyright © 2022 Ivan Izyumkin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

/// Delegate protocol to match user interaction with emoji picker.
public protocol EmojiPickerDelegate: AnyObject {
    /// Provides chosen emoji.
    ///
    /// - Parameter emoji: String emoji.
    func didGetEmoji(emoji: String)
}

/// Emoji Picker view controller. 
public final class EmojiPickerViewController: UIViewController {
    
    // MARK: - Internal Properties
    
    /// Delegate for selecting an emoji object.
    weak var delegate: EmojiPickerDelegate?
    
    /// The view containing the anchor rectangle for the popover.
    var sourceView: UIView? {
        didSet {
            popoverPresentationController?.sourceView = sourceView
        }
    }
    
    /**
     The direction of the arrow for EmojiPicker.
     
     - Note: The default value of this property is `.up`.
     */
    let arrowDirection: PickerArrowDirectionMode
    
    /**
     Custom height for EmojiPicker.
     
     - Note: The default value of this property is `nil`.
     - Important: it will be limited by the distance from `sourceView.origin.y` to the upper or lower bound(depends on `permittedArrowDirections`).
     */
    let customHeight: CGFloat?
    
    /**
     Inset from the sourceView border.
     
     - Note: The default value of this property is `0`.
     */
    let horizontalInset: CGFloat
    
    /**
     A boolean value that determines whether the screen will be hidden after the emoji is selected.
     
     If this property’s value is `true`, the EmojiPicker will be dismissed after the emoji is selected.
     If you want EmojiPicker not to dismissed after emoji selection, you must set this property to `false`.
     
     - Note: The default value of this property is `true`.
     */
    let isDismissAfterChoosing: Bool
    
    /**
     Color for the selected emoji category.
     
     - Note: The default value of this property is `.systemBlue`.
     */
    var selectedEmojiCategoryTintColor: UIColor? {
        didSet {
            guard let selectedEmojiCategoryTintColor = selectedEmojiCategoryTintColor else { return }
            emojiPickerView.selectedEmojiCategoryTintColor = selectedEmojiCategoryTintColor
        }
    }
    
    /**
     Feedback generator style. To turn off, set `nil` to this parameter.
     
     - Note: The default value of this property is `.light`.
     */
    var feedBackGeneratorStyle: UIImpactFeedbackGenerator.FeedbackStyle? {
        didSet {
            guard let feedBackGeneratorStyle = feedBackGeneratorStyle else {
                generator = nil
                return
            }
            generator = UIImpactFeedbackGenerator(style: feedBackGeneratorStyle)
        }
    }
    
    // MARK: - Private Properties
    
    private let emojiPickerView = EmojiPickerView()
    private var generator: UIImpactFeedbackGenerator?
    private var viewModel: EmojiPickerViewModelProtocol
    
    // MARK: - Init
    
    /// Creates EmojiPicker view controller with provided configuration.
    public init(configuration: Configuration) {
        arrowDirection = configuration.arrowDirection
        selectedEmojiCategoryTintColor = configuration.selectedEmojiCategoryTintColor
        horizontalInset = configuration.horizontalInset
        isDismissAfterChoosing = configuration.isDismissAfterChoosing
        customHeight = configuration.customHeight
        
        let unicodeManager = UnicodeManager()
        viewModel = EmojiPickerViewModel(unicodeManager: unicodeManager)
        
        super.init(nibName: nil, bundle: nil)
        
        delegate = configuration.delegate
        sourceView = configuration.sender
        
        setupDelegates()
        bindViewModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    override public func loadView() {
        view = emojiPickerView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationStyle = .popover
        
        setupPreferredContentSize()
        setupArrowDirections()
        setupHorizontalInset()
    }
    
    // MARK: - Private Methods
    
    private func bindViewModel() {
        viewModel.selectedEmoji.bind { [unowned self] emoji in
            generator?.impactOccurred()
            delegate?.didGetEmoji(emoji: emoji)
            if isDismissAfterChoosing {
                dismiss(animated: true, completion: nil)
            }
        }
        viewModel.selectedEmojiCategoryIndex.bind { [unowned self] categoryIndex in
            self.emojiPickerView.updateSelectedCategoryIcon(with: categoryIndex)
        }
    }
    
    private func setupDelegates() {
        emojiPickerView.delegate = self
        emojiPickerView.collectionView.delegate = self
        emojiPickerView.collectionView.dataSource = self
        presentationController?.delegate = self
    }
    
    /// Sets up preferred content size.
    ///
    /// - Note: The number `0.16` was taken based on the proportion of height to the width of the EmojiPicker on MacOS.
    private func setupPreferredContentSize() {
        let sideInset: CGFloat = 20
        let screenWidth: CGFloat = UIScreen.main.nativeBounds.width / UIScreen.main.nativeScale
        let popoverWidth: CGFloat = screenWidth - (sideInset * 2)
        let heightProportionToWidth: CGFloat = 1.16
        
        preferredContentSize = CGSize(width: popoverWidth,
                                      height: customHeight ?? popoverWidth * heightProportionToWidth)
    }
    
    private func setupArrowDirections() {
        popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection(
            rawValue: arrowDirection.rawValue
        )
    }
    
    private func setupHorizontalInset() {
        guard let sourceView = sourceView else { return }
        
        popoverPresentationController?.sourceRect = CGRect(
            x: 0,
            y: popoverPresentationController?.permittedArrowDirections == .up ? horizontalInset : -horizontalInset,
            width: sourceView.frame.width,
            height: sourceView.frame.height
        )
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension EmojiPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.numberOfSections()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItems(in: section)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCollectionViewCell.identifier, for: indexPath) as? EmojiCollectionViewCell
        else { return UICollectionViewCell() }
        
        cell.configure(with: viewModel.emoji(at: indexPath))
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            guard let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: EmojiCollectionViewHeader.identifier, for: indexPath) as? EmojiCollectionViewHeader
            else { return UICollectionReusableView() }
            
            sectionHeader.configure(with: viewModel.sectionHeaderViewModel(for: indexPath.section))
            return sectionHeader
        default:
            return UICollectionReusableView()
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        viewModel.selectedEmoji.value = viewModel.emoji(at: indexPath)
    }
}

// MARK: - UIScrollViewDelegate

extension EmojiPickerViewController: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        /// This code updates the selected category during scrolling.
        let indexPathsForVisibleHeaders = emojiPickerView.collectionView.indexPathsForVisibleSupplementaryElements(
            ofKind: UICollectionView.elementKindSectionHeader
        ).sorted(by: { $0.section < $1.section })
        
        if let selectedEmojiCategoryIndex = indexPathsForVisibleHeaders.first?.section,
           viewModel.selectedEmojiCategoryIndex.value != selectedEmojiCategoryIndex {
            viewModel.selectedEmojiCategoryIndex.value = selectedEmojiCategoryIndex
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EmojiPickerViewController: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 40)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let sideInsets = collectionView.contentInset.right + collectionView.contentInset.left
        let contentSize = collectionView.bounds.width - sideInsets
        return CGSize(width: contentSize / 8, height: contentSize / 8)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}

// MARK: - EmojiPickerViewDelegate

extension EmojiPickerViewController: EmojiPickerViewDelegate {
    
    func didChoiceEmojiCategory(at index: Int) {
        generator?.impactOccurred()
        viewModel.selectedEmojiCategoryIndex.value = index
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension EmojiPickerViewController: UIAdaptivePresentationControllerDelegate {
    
    public func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}
