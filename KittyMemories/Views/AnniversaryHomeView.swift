import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AnniversaryHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AnniversaryEntry.date) private var entries: [AnniversaryEntry]
    @State private var showingCreate = false
    @State private var operationError: String?

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
        .controlSize(.small)
        .navigationTitle("纪念日")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) { CreateAnniversaryView() }
        .alert("操作未完成", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("好", role: .cancel) { operationError = nil }
        } message: {
            Text(operationError ?? "请稍后重试。")
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let removed = offsets.map { entries[$0] }
        let fileNames = removed.flatMap { $0.photos.map(\.fileName) }
        for entry in removed {
            context.delete(entry)
        }
        do {
            try context.save()
            for fileName in fileNames {
                LocalFileStore.delete(fileName, from: .photos)
            }
        } catch {
            context.rollback()
            operationError = "删除纪念日失败：\(error.localizedDescription)"
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
                            let fileName = photo.fileName
                            entry.photos.removeAll { $0.id == photo.id }
                            context.delete(photo)
                            do {
                                try context.save()
                                LocalFileStore.delete(fileName, from: .photos)
                            } catch {
                                context.rollback()
                                importError = "删除照片失败：\(error.localizedDescription)"
                            }
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
            do {
                let photo = AnniversaryPhoto(fileName: name, anniversary: entry)
                entry.photos.append(photo)
                context.insert(photo)
                try context.save()
            } catch {
                LocalFileStore.delete(name, from: .photos)
                throw error
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    private enum PhotoImportError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "无法读取所选图片，请换一张照片重试。" }
    }
}
