platform :ios, '11.0'
use_frameworks!

target 'ReadingList' do
  pod 'DZNEmptyDataSet', '~> 1.8'
  pod 'SwiftyJSON', '~> 5.0'
  pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :commit => '6a79d4b7d49def9adcb0a17ec2a652bb081e1ad8'
  pod 'ImageRow', '~> 4.0'
  pod 'SVProgressHUD', '~> 2.2'
  pod 'SwiftyStoreKit', '~> 0.15'
  pod 'CHCSVParser', :git => 'https://github.com/davedelong/CHCSVParser.git'
  pod 'PromisesSwift', '~> 1.2'
  pod 'Cosmos', '~> 19.0'
  pod 'SimulatorStatusMagic', :configurations => ['Debug']
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'Firebase/Core'

  target 'ReadingList_UnitTests' do
    inherit! :complete
    pod 'SwiftyJSON', '~> 5.0'
    pod 'Swifter', :git => 'https://github.com/httpswift/swifter.git', :branch => 'stable'
  end
  target 'ReadingList_UITests' do
    inherit! :complete
    pod 'Swifter', :git => 'https://github.com/httpswift/swifter.git', :branch => 'stable'
  end
  target 'ReadingList_Screenshots' do
    inherit! :complete
    pod 'Swifter', :git => 'https://github.com/httpswift/swifter.git', :branch => 'stable'
  end

end
