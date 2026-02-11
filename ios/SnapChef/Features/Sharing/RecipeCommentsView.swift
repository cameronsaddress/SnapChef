import SwiftUI
import CloudKit

// MARK: - Comment Model
struct CommentItem: Identifiable {
    let id: String
    let userID: String
    let userName: String
    let userPhoto: UIImage?
    let recipeID: String
    let content: String
    let createdAt: Date
    let editedAt: Date?
    let likeCount: Int
    let isLiked: Bool
    let parentCommentID: String?
    let replies: [CommentItem]

    var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Recipe Comments View
struct RecipeCommentsView: View {
    let recipe: Recipe
    @StateObject private var viewModel = RecipeCommentsViewModel()
    @State private var commentText = ""
    @State private var replyingTo: CommentItem?
    @State private var showingReportSheet = false
    @State private var reportedComment: CommentItem?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Comments List
                    if viewModel.isLoading && viewModel.comments.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Spacer()
                    } else if viewModel.comments.isEmpty {
                        EmptyCommentsView()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(viewModel.comments) { comment in
                                        CommentItemView(
                                            comment: comment,
                                            onReply: {
                                                replyingTo = comment
                                                isInputFocused = true
                                            },
                                            onLike: {
                                                Task {
                                                    await viewModel.toggleLike(comment)
                                                }
                                            },
                                            onReport: {
                                                reportedComment = comment
                                                showingReportSheet = true
                                            }
                                        )
                                        .id(comment.id)
                                    }

                                    if viewModel.hasMore {
                                        ProgressView()
                                            .tint(.white)
                                            .padding()
                                            .onAppear {
                                                Task {
                                                    await viewModel.loadMore()
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .onChange(of: viewModel.comments.count) { _ in
                                // Scroll to newest comment when added
                                if let lastComment = viewModel.comments.first {
                                    withAnimation {
                                        proxy.scrollTo(lastComment.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    // Comment Input
                    CommentInputView(
                        text: $commentText,
                        replyingTo: $replyingTo,
                        isFocused: $isInputFocused,
                        onSend: {
                            Task {
                                await sendComment()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            await viewModel.loadComments(for: recipe.id.uuidString)
        }
        .sheet(isPresented: $showingReportSheet) {
            if let comment = reportedComment {
                ReportCommentSheet(comment: comment) { reason in
                    Task {
                        await viewModel.reportComment(comment, reason: reason)
                    }
                }
            }
        }
    }

    private func sendComment() async {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        await viewModel.addComment(
            to: recipe.id.uuidString,
            content: trimmedText,
            parentCommentID: replyingTo?.id
        )

        commentText = ""
        replyingTo = nil
        isInputFocused = false
    }
}

// MARK: - Comment Item View
struct CommentItemView: View {
    let comment: CommentItem
    let onReply: () -> Void
    let onLike: () -> Void
    let onReport: () -> Void

    @State private var showReplies = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main Comment
            HStack(alignment: .top, spacing: 12) {
                // User Avatar
                if let photo = comment.userPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(comment.userName.prefix(1).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    // User Info
                    HStack {
                        Text(comment.userName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text("•")
                            .foregroundColor(.white.opacity(0.5))

                        Text(comment.timeAgoText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))

                        if comment.editedAt != nil {
                            Text("(edited)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Menu {
                            Button(action: onReport) {
                                Label("Report", systemImage: "exclamationmark.triangle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    // Comment Content
                    Text(comment.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    // Actions
                    HStack(spacing: 20) {
                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(comment.isLiked ? .red : .white.opacity(0.6))

                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: onReply) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 14))
                                Text("Reply")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(PlainButtonStyle())

                        if !comment.replies.isEmpty {
                            Button(action: {
                                withAnimation {
                                    showReplies.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12))
                                    Text("\(comment.replies.count) replies")
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(Color(hex: "#667eea"))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }

            // Replies
            if showReplies && !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(comment.replies) { reply in
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 2)
                                .padding(.leading, 20)

                            CommentItemView(
                                comment: reply,
                                onReply: onReply,
                                onLike: onLike,
                                onReport: onReport
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Comment Input View
struct CommentInputView: View {
    @Binding var text: String
    @Binding var replyingTo: CommentItem?
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingTo {
                HStack {
                    Text("Replying to \(replyingTo.userName)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Button(action: {
                        self.replyingTo = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
            }

            HStack(spacing: 12) {
                TextField("Add a comment...", text: $text, axis: .vertical)
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        onSend()
                    }

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(text.isEmpty ? .white.opacity(0.3) : Color(hex: "#667eea"))
                }
                .disabled(text.isEmpty)
            }
            .padding(16)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1),
                        alignment: .top
                    )
            )
        }
    }
}

// MARK: - Empty Comments View
struct EmptyCommentsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            Text("No comments yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Be the first to share your thoughts\nabout this recipe!")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Report Comment Sheet
struct ReportCommentSheet: View {
    let comment: CommentItem
    let onReport: (String) -> Void
    @Environment(\.dismiss) var dismiss

    let reportReasons = [
        "Spam or misleading",
        "Inappropriate content",
        "Harassment or bullying",
        "False information",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text("Why are you reporting this comment?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ForEach(reportReasons, id: \.self) { reason in
                        Button(action: {
                            onReport(reason)
                            dismiss()
                        }) {
                            HStack {
                                Text(reason)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Report Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Recipe Comments View Model
@MainActor
class RecipeCommentsViewModel: ObservableObject {
    @Published var comments: [CommentItem] = []
    @Published var isLoading = false
    @Published var hasMore = true

    private let cloudKitSync = CloudKitService.shared
    private let cloudKitAuth = UnifiedAuthManager.shared
    private var lastFetchedRecord: CKRecord?
    private var recipeID: String = ""

    func loadComments(for recipeID: String) async {
        self.recipeID = recipeID
        isLoading = true
        comments = []
        lastFetchedRecord = nil
        hasMore = true

        print("🔍 Loading comments for recipe: \(recipeID)")

        do {
            let ckRecords = try await cloudKitSync.fetchComments(for: recipeID, limit: 50)
            print("✅ Fetched \(ckRecords.count) comment records from CloudKit")
            
            let commentItems = await parseCommentsFromRecords(ckRecords)
            print("✅ Parsed \(commentItems.count) comment items")
            
            comments = organizeCommentsWithReplies(commentItems)
            print("✅ Organized into \(comments.count) top-level comments")
            
            hasMore = ckRecords.count >= 50
        } catch {
            print("❌ Failed to load comments for recipe \(recipeID): \(error)")
            // Fall back to empty state on error
            comments = []
            hasMore = false
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true

        // For now, we'll load all comments at once
        // Future enhancement: implement proper pagination with cursor
        hasMore = false

        isLoading = false
    }

    func refresh() async {
        await loadComments(for: recipeID)
    }

    func addComment(to recipeID: String, content: String, parentCommentID: String? = nil) async {
        guard let userID = cloudKitAuth.currentUser?.recordID,
              let userName = cloudKitAuth.currentUser?.displayName else { 
            print("❌ Cannot add comment: User not authenticated")
            return 
        }

        // Create comment for immediate UI update
        let commentID = UUID().uuidString
        let newComment = CommentItem(
            id: commentID,
            userID: userID,
            userName: userName,
            userPhoto: nil,
            recipeID: recipeID,
            content: content,
            createdAt: Date(),
            editedAt: nil,
            likeCount: 0,
            isLiked: false,
            parentCommentID: parentCommentID,
            replies: []
        )

        // Add to UI immediately for better UX
        if let parentCommentID = parentCommentID,
           let parentIndex = comments.firstIndex(where: { $0.id == parentCommentID }) {
            // Add as reply
            let updatedParent = comments[parentIndex]
            var replies = updatedParent.replies
            replies.append(newComment)

            comments[parentIndex] = CommentItem(
                id: updatedParent.id,
                userID: updatedParent.userID,
                userName: updatedParent.userName,
                userPhoto: updatedParent.userPhoto,
                recipeID: updatedParent.recipeID,
                content: updatedParent.content,
                createdAt: updatedParent.createdAt,
                editedAt: updatedParent.editedAt,
                likeCount: updatedParent.likeCount,
                isLiked: updatedParent.isLiked,
                parentCommentID: updatedParent.parentCommentID,
                replies: replies
            )
        } else {
            // Add as top-level comment
            comments.insert(newComment, at: 0)
        }

        do {
            // Save to CloudKit
            try await cloudKitSync.addComment(
                recipeID: recipeID,
                content: content,
                parentCommentID: parentCommentID
            )
            print("✅ Comment successfully saved to CloudKit")
            
        } catch {
            print("❌ Failed to save comment to CloudKit: \(error)")
            
            // Remove from UI if CloudKit save failed
            if let parentCommentID = parentCommentID,
               let parentIndex = comments.firstIndex(where: { $0.id == parentCommentID }) {
                // Remove from replies
                let updatedParent = comments[parentIndex]
                let filteredReplies = updatedParent.replies.filter { $0.id != commentID }
                
                comments[parentIndex] = CommentItem(
                    id: updatedParent.id,
                    userID: updatedParent.userID,
                    userName: updatedParent.userName,
                    userPhoto: updatedParent.userPhoto,
                    recipeID: updatedParent.recipeID,
                    content: updatedParent.content,
                    createdAt: updatedParent.createdAt,
                    editedAt: updatedParent.editedAt,
                    likeCount: updatedParent.likeCount,
                    isLiked: updatedParent.isLiked,
                    parentCommentID: updatedParent.parentCommentID,
                    replies: filteredReplies
                )
            } else {
                // Remove from top-level comments
                comments.removeAll { $0.id == commentID }
            }
            
            // TODO: Show error toast to user
        }
    }

    func toggleLike(_ comment: CommentItem) async {
        // Update local state immediately for better UX
        updateCommentInList(comment) { current in
            CommentItem(
                id: current.id,
                userID: current.userID,
                userName: current.userName,
                userPhoto: current.userPhoto,
                recipeID: current.recipeID,
                content: current.content,
                createdAt: current.createdAt,
                editedAt: current.editedAt,
                likeCount: current.isLiked ? max(0, current.likeCount - 1) : current.likeCount + 1,
                isLiked: !current.isLiked,
                parentCommentID: current.parentCommentID,
                replies: current.replies
            )
        }

        do {
            if comment.isLiked {
                try await cloudKitSync.unlikeComment(comment.id)
            } else {
                try await cloudKitSync.likeComment(comment.id)
            }
        } catch {
            // Revert local state on error
            updateCommentInList(comment) { current in
                CommentItem(
                    id: current.id,
                    userID: current.userID,
                    userName: current.userName,
                    userPhoto: current.userPhoto,
                    recipeID: current.recipeID,
                    content: current.content,
                    createdAt: current.createdAt,
                    editedAt: current.editedAt,
                    likeCount: comment.likeCount, // Revert to original
                    isLiked: comment.isLiked, // Revert to original
                    parentCommentID: current.parentCommentID,
                    replies: current.replies
                )
            }
            print("Failed to toggle comment like: \(error)")
        }
    }

    func reportComment(_ comment: CommentItem, reason: String) async {
        // CloudKit reporting system not implemented yet
        // In a production app, this would:
        // 1. Create a CommentReport record in CloudKit
        // 2. Flag the comment for moderation
        // 3. Potentially hide the comment for the reporting user
        print("Reported comment \(comment.id) for: \(reason)")
    }
    
    func deleteComment(_ comment: CommentItem) async {
        do {
            try await cloudKitSync.deleteComment(comment.id)
            
            // Remove from local state
            if comment.parentCommentID != nil {
                // Remove reply
                updateCommentInList(comment) { _ in nil }
            } else {
                // Remove top-level comment
                comments.removeAll { $0.id == comment.id }
            }
        } catch {
            print("Failed to delete comment: \(error)")
        }
    }

    // MARK: - CloudKit Integration Helper Methods
    
    private func parseCommentsFromRecords(_ records: [CKRecord]) async -> [CommentItem] {
        var commentItems: [CommentItem] = []
        
        for record in records {
            if let commentItem = await parseCommentFromRecord(record) {
                commentItems.append(commentItem)
            }
        }
        
        return commentItems
    }
    
    private func parseCommentFromRecord(_ record: CKRecord) async -> CommentItem? {
        print("🔍 Parsing comment record: \(record.recordID.recordName)")
        print("📝 Record fields: \(record.allKeys())")
        
        guard let id = record[CKField.RecipeComment.id] as? String,
              let userID = record[CKField.RecipeComment.userID] as? String,
              let recipeID = record[CKField.RecipeComment.recipeID] as? String,
              let content = record[CKField.RecipeComment.content] as? String,
              let createdAt = record[CKField.RecipeComment.createdAt] as? Date else {
            print("❌ Failed to parse comment from CloudKit record: missing required fields")
            print("   - id: \(record[CKField.RecipeComment.id] as? String ?? "missing")")
            print("   - userID: \(record[CKField.RecipeComment.userID] as? String ?? "missing")")
            print("   - recipeID: \(record[CKField.RecipeComment.recipeID] as? String ?? "missing")")
            print("   - content: \(record[CKField.RecipeComment.content] as? String ?? "missing")")
            let createdAtValue = record[CKField.RecipeComment.createdAt] as? Date
            print("   - createdAt: \(createdAtValue?.formatted(date: .abbreviated, time: .shortened) ?? "missing")")
            return nil
        }
        
        print("✅ Successfully extracted basic comment fields")
        
        // Get user display name (this could be cached or fetched from User records)
        let userName = await getUserDisplayName(for: userID) ?? "Unknown User"
        
        let editedAt = record[CKField.RecipeComment.editedAt] as? Date
        let likeCount = Int(record[CKField.RecipeComment.likeCount] as? Int64 ?? 0)
        let parentCommentID = record[CKField.RecipeComment.parentCommentID] as? String
        
        // Resolve current user's like state for this comment.
        let isLiked = (try? await cloudKitSync.isCommentLiked(id)) ?? false
        
        let commentItem = CommentItem(
            id: id,
            userID: userID,
            userName: userName,
            userPhoto: nil, // TODO: Load user photos
            recipeID: recipeID,
            content: content,
            createdAt: createdAt,
            editedAt: editedAt,
            likeCount: likeCount,
            isLiked: isLiked,
            parentCommentID: parentCommentID,
            replies: []
        )
        
        print("✅ Created CommentItem: \(commentItem.content)")
        return commentItem
    }
    
    private func organizeCommentsWithReplies(_ commentItems: [CommentItem]) -> [CommentItem] {
        var topLevelComments: [CommentItem] = []
        var repliesMap: [String: [CommentItem]] = [:]
        
        // Separate top-level comments and replies
        for comment in commentItems {
            if comment.parentCommentID == nil {
                topLevelComments.append(comment)
            } else if let parentID = comment.parentCommentID {
                if repliesMap[parentID] == nil {
                    repliesMap[parentID] = []
                }
                repliesMap[parentID]?.append(comment)
            }
        }
        
        // Attach replies to their parent comments
        return topLevelComments.map { comment in
            let replies = repliesMap[comment.id] ?? []
            return CommentItem(
                id: comment.id,
                userID: comment.userID,
                userName: comment.userName,
                userPhoto: comment.userPhoto,
                recipeID: comment.recipeID,
                content: comment.content,
                createdAt: comment.createdAt,
                editedAt: comment.editedAt,
                likeCount: comment.likeCount,
                isLiked: comment.isLiked,
                parentCommentID: comment.parentCommentID,
                replies: replies.sorted { $0.createdAt < $1.createdAt }
            )
        }.sorted { $0.createdAt > $1.createdAt } // Most recent first
    }
    
    private func getUserDisplayName(for userID: String) async -> String? {
        // If it's the current user, use their display name
        if let currentUser = cloudKitAuth.currentUser,
           currentUser.recordID == userID {
            return currentUser.displayName
        }
        
        // TODO: Implement user name caching/fetching from CloudKit User records
        // This should maintain a cache of user names to avoid repeated fetches
        // For now, return a generic placeholder
        return "SnapChef User"
    }
    
    private func updateCommentInList(_ targetComment: CommentItem, transform: (CommentItem) -> CommentItem?) {
        for i in 0..<comments.count {
            let comment = comments[i]
            
            // Check if this is the target comment
            if comment.id == targetComment.id {
                if let updated = transform(comment) {
                    comments[i] = updated
                } else {
                    comments.remove(at: i)
                }
                return
            }
            
            // Check replies
            for j in 0..<comment.replies.count {
                let reply = comment.replies[j]
                if reply.id == targetComment.id {
                    var updatedReplies = comment.replies
                    if let updated = transform(reply) {
                        updatedReplies[j] = updated
                    } else {
                        updatedReplies.remove(at: j)
                    }
                    
                    comments[i] = CommentItem(
                        id: comment.id,
                        userID: comment.userID,
                        userName: comment.userName,
                        userPhoto: comment.userPhoto,
                        recipeID: comment.recipeID,
                        content: comment.content,
                        createdAt: comment.createdAt,
                        editedAt: comment.editedAt,
                        likeCount: comment.likeCount,
                        isLiked: comment.isLiked,
                        parentCommentID: comment.parentCommentID,
                        replies: updatedReplies
                    )
                    return
                }
            }
        }
    }
}

#Preview {
    RecipeCommentsView(recipe: MockDataProvider.shared.mockRecipe())
        .environmentObject(AppState())
}
