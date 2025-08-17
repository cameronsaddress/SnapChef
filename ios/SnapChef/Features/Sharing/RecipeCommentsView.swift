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

    private let cloudKitSync = CloudKitSyncService.shared
    private let cloudKitAuth = CloudKitAuthManager.shared
    private var lastFetchedRecord: CKRecord?
    private var recipeID: String = ""

    func loadComments(for recipeID: String) async {
        self.recipeID = recipeID
        isLoading = true
        comments = []
        lastFetchedRecord = nil

        // For now, load mock data
        // CloudKit comments integration not implemented - using mock data for demo
        comments = generateMockComments()
        hasMore = false

        isLoading = false
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true

        // CloudKit pagination not implemented - using mock data for demo

        isLoading = false
    }

    func refresh() async {
        await loadComments(for: recipeID)
    }

    func addComment(to recipeID: String, content: String, parentCommentID: String? = nil) async {
        guard let userID = cloudKitAuth.currentUser?.recordID,
              let userName = cloudKitAuth.currentUser?.displayName else { return }

        // Create temporary comment for immediate UI update
        let newComment = CommentItem(
            id: UUID().uuidString,
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

        if let parentCommentID = parentCommentID,
           let parentIndex = comments.firstIndex(where: { $0.id == parentCommentID }) {
            // Add as reply
            var updatedParent = comments[parentIndex]
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

        // CloudKit comment saving not implemented - storing locally
        do {
            try await cloudKitSync.addComment(
                recipeID: recipeID,
                content: content,
                parentCommentID: parentCommentID
            )
        } catch {
            print("Failed to save comment: \(error)")
        }
    }

    func toggleLike(_ comment: CommentItem) async {
        // Update local state immediately
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            let updatedComment = CommentItem(
                id: comment.id,
                userID: comment.userID,
                userName: comment.userName,
                userPhoto: comment.userPhoto,
                recipeID: comment.recipeID,
                content: comment.content,
                createdAt: comment.createdAt,
                editedAt: comment.editedAt,
                likeCount: comment.isLiked ? comment.likeCount - 1 : comment.likeCount + 1,
                isLiked: !comment.isLiked,
                parentCommentID: comment.parentCommentID,
                replies: comment.replies
            )
            comments[index] = updatedComment
        }

        // CloudKit comment updates not implemented
    }

    func reportComment(_ comment: CommentItem, reason: String) async {
        // CloudKit reporting not implemented - logging locally
        print("Reported comment \(comment.id) for: \(reason)")
    }

    private func generateMockComments() -> [CommentItem] {
        [
            CommentItem(
                id: UUID().uuidString,
                userID: "user1",
                userName: "Julia Child",
                userPhoto: nil,
                recipeID: recipeID,
                content: "This looks absolutely delicious! I love how you've presented it. The colors are so vibrant!",
                createdAt: Date().addingTimeInterval(-3_600),
                editedAt: nil,
                likeCount: 15,
                isLiked: false,
                parentCommentID: nil,
                replies: [
                    CommentItem(
                        id: UUID().uuidString,
                        userID: "user2",
                        userName: "Gordon Ramsay",
                        userPhoto: nil,
                        recipeID: recipeID,
                        content: "Couldn't agree more! The plating is spot on.",
                        createdAt: Date().addingTimeInterval(-1_800),
                        editedAt: nil,
                        likeCount: 5,
                        isLiked: true,
                        parentCommentID: "parent1",
                        replies: []
                    )
                ]
            ),
            CommentItem(
                id: UUID().uuidString,
                userID: "user3",
                userName: "Home Cook",
                userPhoto: nil,
                recipeID: recipeID,
                content: "Made this last night and my family loved it! Thanks for sharing 🙏",
                createdAt: Date().addingTimeInterval(-7_200),
                editedAt: nil,
                likeCount: 8,
                isLiked: false,
                parentCommentID: nil,
                replies: []
            ),
            CommentItem(
                id: UUID().uuidString,
                userID: "user4",
                userName: "FoodieFan",
                userPhoto: nil,
                recipeID: recipeID,
                content: "What temperature did you cook this at? Looks perfect!",
                createdAt: Date().addingTimeInterval(-10_800),
                editedAt: Date().addingTimeInterval(-9_000),
                likeCount: 2,
                isLiked: false,
                parentCommentID: nil,
                replies: []
            )
        ]
    }
}

#Preview {
    RecipeCommentsView(recipe: MockDataProvider.shared.mockRecipe())
        .environmentObject(AppState())
}
