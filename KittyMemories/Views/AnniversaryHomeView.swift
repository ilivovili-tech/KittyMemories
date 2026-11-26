import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AnniversaryHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AnniversaryEntry.date) private var entries: [AnniversaryEntry]
    @State private var showingCreate = false

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink { AnniversaryDetailView(entry: entry) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.title).font(.headline)
                        Text(entry.date.formatted(date: .long, time: .omitted)).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .navigationTitle("纪念日")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) { CreateAnniversaryView() }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            for photo in entry.photos {
                LocalFileStore.delete(photo.fileName, from: .photos)
            }
            context.delete(entry)
        }
    }
}

private struct CreateAnniversaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                TextField("纪念日名称", text: $title)
                DatePicker("日期", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("新建纪念日")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        context.insert(AnniversaryEntry(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AnniversaryDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: AnniversaryEntry
    @State private var selectedItem: PhotosPickerItem?
    @State private var importError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(entry.date.formatted(date: .complete, time: .omitted)).font(.title3)
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("添加纪念日照片", systemImage: "plus")
                        .padding()
                        .glassEffect(.regular, in: .capsule)
                }
                ForEach(entry.photos) { photo in
                    ZStack(alignment: .topTrailing) {
                        if let url = LocalFileStore.url(photo.fileName, in: .photos),
                           let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        } else {
                            ContentUnavailableView("照片文件不存在", systemImage: "photo")
                        }
                        Button(role: .destructive) {
                            LocalFileStore.delete(photo.fileName, from: .photos)
                            entry.photos.removeAll { $0.id == photo.id }
                            context.delete(photo)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                                .padding(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(entry.title)
        .onChange(of: selectedItem) { _, item in Task { await addPhoto(item) } }
        .alert("无法添加照片", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "请稍后重试。")
        }
    }

    @MainActor private func addPhoto(_ item: PhotosPickerItem?) async {
        defer { selectedItem = nil }
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.94) else {
                throw PhotoImportError.invalidImage
            }
            let name = try LocalFileStore.save(jpeg, in: .photos)
            let photo = AnniversaryPhoto(fileName: name, anniversary: entry)
            entry.photos.append(photo)
            context.insert(photo)
            try context.save()
        } catch {
            importError = error.localizedDescription
        }
    }

    private enum PhotoImportError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "无法读取所选图片，请换一张照片重试。" }
    }
}
