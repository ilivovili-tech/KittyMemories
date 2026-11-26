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
            }.onDelete { offsets in offsets.map { entries[$0] }.forEach(context.delete) }
        }.navigationTitle("纪念日")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showingCreate) { CreateAnniversaryView() }
    }
}
private struct CreateAnniversaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var date = Date.now
    var body: some View {
        NavigationStack {
            Form { TextField("纪念日名称", text: $title); DatePicker("日期", selection: $date, displayedComponents: .date) }
                .navigationTitle("新建纪念日")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { context.insert(AnniversaryEntry(title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: date)); dismiss() }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
private struct AnniversaryDetailView: View {
    @Bindable var entry: AnniversaryEntry
    @State private var selectedItem: PhotosPickerItem?
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(entry.date.formatted(date: .complete, time: .omitted)).font(.title3)
                PhotosPicker(selection: $selectedItem, matching: .images) { Label("添加纪念日照片", systemImage: "plus").padding().glassEffect(.regular, in: .capsule) }
                ForEach(entry.photos) { photo in
                    if let url = LocalFileStore.url(photo.fileName, in: .photos), let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }.padding()
        }.navigationTitle(entry.title).onChange(of: selectedItem) { _, item in Task { await addPhoto(item) } }
    }
    @MainActor private func addPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.94) else { return }
        do { let name = try LocalFileStore.save(jpeg, in: .photos); entry.photos.append(AnniversaryPhoto(fileName: name, anniversary: entry)) }
        catch { print("Anniversary photo import failed: \(error)") }
        selectedItem = nil
    }
}
