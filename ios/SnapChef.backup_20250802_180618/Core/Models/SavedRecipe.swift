import Foundation
import UIKit

struct SavedRecipe: Codable {
    let recipe: Recipe
    let beforePhotoData: Data?
    let afterPhotoData: Data?
    let savedAt: Date
    
    init(recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) {
        self.recipe = recipe
        self.beforePhotoData = beforePhoto?.jpegData(compressionQuality: 0.8)
        self.afterPhotoData = afterPhoto?.jpegData(compressionQuality: 0.8)
        self.savedAt = Date()
    }
    
    var beforePhoto: UIImage? {
        guard let data = beforePhotoData else { return nil }
        return UIImage(data: data)
    }
    
    var afterPhoto: UIImage? {
        guard let data = afterPhotoData else { return nil }
        return UIImage(data: data)
    }
}