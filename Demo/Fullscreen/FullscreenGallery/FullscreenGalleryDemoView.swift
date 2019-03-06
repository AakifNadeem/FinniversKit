//
// Copyright (c) 2019 FINN AS. All rights reserved.
//

import FinniversKit

// MARK: - Helpers

private protocol SelectedIndexDelegate: class {
    func selectedIndexChanged(to index: Int)
}

private struct DemoViewModel: FullscreenGalleryViewModel {
    public weak var selectedIndexDelegate: SelectedIndexDelegate?

    let imageUrls: [String]
    let imageCaptions: [String]
    var selectedIndex: Int {
        didSet {
            selectedIndexDelegate?.selectedIndexChanged(to: selectedIndex)
        }
    }
}

private class DemoPreviewCell: UICollectionViewCell {
    private(set) var imageIndex: Int?
    private(set) var imageUrl: String?

    private(set) lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: .mediumSpacing),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -.mediumSpacing),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: .mediumSpacing),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -.mediumSpacing),
        ])
    }

    // MARK: - Lifecycle

    override func prepareForReuse() {
        super.prepareForReuse()

        imageView.image = nil
        imageUrl = nil
        imageIndex = nil
    }

    // MARK: - Public methods

    public func configure(withIndex index: Int, url: String) {
        imageUrl = url
        imageIndex = index

        ImageDownloader.shared.downloadImage(withUrl: url, dataCallback: { [weak self] (fetchedUrl, image, error) in
            guard let self = self else { return }
            if fetchedUrl == self.imageUrl {
                self.imageView.image = image
            }
        })
    }
}

private class ImageDownloader: FullscreenGalleryImageSource {
    static let shared = ImageDownloader()

    public var simulatedDelayMs: UInt32 = 0

    public func downloadImage(withUrl urlString: String, dataCallback: @escaping (String, UIImage?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            dataCallback(urlString, nil, nil)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [simulatedDelayMs] data, _, _ in
            if simulatedDelayMs != 0 {
                usleep(simulatedDelayMs * 1000)
            }

            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    dataCallback(urlString, image, nil)
                } else {
                    dataCallback(urlString, nil, nil)
                }
            }
        }

        task.resume()
    }

    func image(forUrlString urlString: String, width: CGFloat, completionHandler handler: @escaping (String, UIImage?, Error?) -> Void) {
        // The size is not taken into account in the demo.
        downloadImage(withUrl: urlString, dataCallback: handler)
    }
}

// MARK: - Demo view

class FullscreenGalleryDemoView: UIView {

    // MARK: - Public properties

    var parentViewController: UIViewController?

    // MARK: - Private properties

    let imageUrls: [String] = [
        "https://i.pinimg.com/736x/73/de/32/73de32f9e5a0db66ec7805bb7cb3f807--navy-blue-houses-blue-and-white-houses-exterior.jpg",
        "http://i3.au.reastatic.net/home-ideas/raw/a96671bab306bcb39783bc703ac67f0278ffd7de0854d04b7449b2c3ae7f7659/facades.jpg",
        "http://jonvilma.com/images/house-6.jpg",
        "https://i.pinimg.com/736x/11/f0/79/11f079c03af31321fd5029f72a4586b1--exterior-houses-house-exteriors.jpg",
        "https://i.pinimg.com/736x/bf/6d/73/bf6d73ab0234f3ba1a615b22d2dc7e74--home-exterior-design-contemporary-houses.jpg"
    ]

    let imageCaptions: [String] = [
        "Blått hus. Bjørnen følger ikke med.",
        "Flytt inn i Syden – hjemme!",
        "Dette er den lang tekst. Det er mange som den, men denne er min. Uten den lange teksten min er jeg ingenting. Uten meg er den lange teksten min ingenting.",
        "Herskapelig og fint.\nMerk mangelen på rovdyr i hagen.",
        "Live here or be square 📦",
    ]

    private var selectedIndex: Int?

    private lazy var transitionController = FullscreenGalleryTransitioningController(withPresenterDelegate: self)

    private lazy var collectionCellHeight: CGFloat = {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return 250.0
        default:
            return 170.0
        }
    }()

    // MARK: - UI properties

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: collectionCellHeight, height: collectionCellHeight)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .black
        collectionView.register(DemoPreviewCell.self)
        return collectionView
    }()

    private lazy var thumbnailSwitch: UISwitch = {
        let switchView = UISwitch(frame: .zero)
        switchView.translatesAutoresizingMaskIntoConstraints = false
        switchView.isSelected = false
        return switchView
    }()

    private lazy var thumbnailLabel: Label = {
        let label = Label(style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .left
        label.text = "Show thumbnails immediately"
        return label
    }()

    private lazy var simulateLoadingSwitch: UISwitch = {
        let switchView = UISwitch(frame: .zero)
        switchView.translatesAutoresizingMaskIntoConstraints = false
        switchView.isSelected = false
        switchView.addTarget(self, action: #selector(loadSimulationSwitchToggled), for: .valueChanged)
        return switchView
    }()

    private lazy var simulateLoadingLabel: Label = {
        let label = Label(style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .left
        label.text = "Simulate 200ms image load delay"
        return label
    }()

    private lazy var helpLabel: Label = {
        let label = Label(style: .title2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.text = "Tap an image to open the fullscreen gallery"
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        addSubview(collectionView)
        addSubview(thumbnailSwitch)
        addSubview(thumbnailLabel)
        addSubview(simulateLoadingSwitch)
        addSubview(simulateLoadingLabel)
        addSubview(helpLabel)

        NSLayoutConstraint.activate([
            collectionView.heightAnchor.constraint(equalToConstant: collectionCellHeight + CGFloat.largeSpacing),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.centerYAnchor.constraint(equalTo: centerYAnchor),

            thumbnailSwitch.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: .largeSpacing),
            thumbnailSwitch.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .largeSpacing),

            thumbnailLabel.leadingAnchor.constraint(equalTo: thumbnailSwitch.trailingAnchor, constant: .mediumLargeSpacing),
            thumbnailLabel.centerYAnchor.constraint(equalTo: thumbnailSwitch.centerYAnchor),

            simulateLoadingSwitch.topAnchor.constraint(equalTo: thumbnailSwitch.bottomAnchor, constant: .mediumSpacing),
            simulateLoadingSwitch.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .largeSpacing),

            simulateLoadingLabel.leadingAnchor.constraint(equalTo: simulateLoadingSwitch.trailingAnchor, constant: .mediumLargeSpacing),
            simulateLoadingLabel.centerYAnchor.constraint(equalTo: simulateLoadingSwitch.centerYAnchor),

            helpLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .mediumLargeSpacing),
            helpLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -.mediumLargeSpacing),
            helpLabel.topAnchor.constraint(equalTo: topAnchor, constant: .largeSpacing),

        ])
    }

    // MARK: - Private methods

    private func displayFullscreenGallery(forIndex index: Int) {
        if let viewController = parentViewController {
            let viewModel = DemoViewModel(selectedIndexDelegate: self, imageUrls: imageUrls, imageCaptions: imageCaptions, selectedIndex: index)

            let gallery = FullscreenGalleryViewController(withImageSource: ImageDownloader.shared, viewModel: viewModel, thumbnailsInitiallyVisible: thumbnailSwitch.isOn)
            gallery.transitioningDelegate = transitionController

            viewController.present(gallery, animated: true)
        }
    }

    @objc private func loadSimulationSwitchToggled() {
        if simulateLoadingSwitch.isOn {
            ImageDownloader.shared.simulatedDelayMs = 200
        } else {
            ImageDownloader.shared.simulatedDelayMs = 0
        }
    }
}

// MARK: - FullscreenGalleryTransitionSourceDelegate

extension FullscreenGalleryDemoView: FullscreenGalleryTransitionPresenterDelegate {
    public func imageViewForFullscreenGalleryTransition() -> UIImageView? {
        let indexPath = IndexPath(row: selectedIndex ?? 0, section: 0)
        let cell = collectionView.cellForItem(at: indexPath) as? DemoPreviewCell
        return cell?.imageView
    }
}

// MARK: - UICollectionView

extension FullscreenGalleryDemoView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(DemoPreviewCell.self, for: indexPath)
        cell.configure(withIndex: indexPath.row, url: imageUrls[indexPath.row])
        return cell
    }
}

extension FullscreenGalleryDemoView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        displayFullscreenGallery(forIndex: indexPath.row)
    }
}

// MARK: - SelectedIndexDelegate

extension FullscreenGalleryDemoView: SelectedIndexDelegate {
    fileprivate func selectedIndexChanged(to index: Int) {
        selectedIndex = index
        let indexPath = IndexPath(row: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
    }
}
