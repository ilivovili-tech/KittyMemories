import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AlbumHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PhotoEntry.customDate, order: .reverse) private var entries: [PhotoEntry]
    @State private var selectedItem: PhotosPickerItem?
    @State private var mode: BrowseMode = .book
    @State private var selectedYear: Int?
    @State private var selectedMonth: Int?
    @State private var selectedDay: Date?
    enum BrowseMode: String, CaseIterable { case book = "翻书", scroll = "滚动" }
    private var years: [Int] { Array(Set(entries.map { Calendar.current.component(.year, from: $0.customDate) })).sorted(by: >) }
    private var months: [Int] {
        guard let year = selectedYear else { return [] }
        return Array(Set(entries.filter { Calendar.current.component(.year, from: $0.customDate) == year }.map { Calendar.current.component(.month, from: $0.customDate) })).sorted(by: >)
    }
    private var days: [Date] {
        guard let year = selectedYear, let month = selectedMonth else { return [] }
        let cal = Calendar.current
        return Array(Set(entries.filter { cal.component(.year, from: $0.customDate) == year && cal.component(.month, from: $0.customDate) == month }.map { cal.startOfDay(for: $0.customDate) })).sorted(by: >)
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("浏览模式", selection: $mode) { ForEach(BrowseMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                PhotosPicker(selection: $selectedItem, matching: .images) { Image(systemName: "plus").font(.title3).padding(11).glassEffect(.regular, in: .circle) }
            }.padding(.horizontal)
            if let day = selectedDay {
                DayAlbumView(day: day, mode: mode, entries: entries.filter { Calendar.current.isDate($0.customDate, inSameDayAs: day) }, onBack: { selectedDay = nil })
            } else if let month = selectedMonth, let year = selectedYear {
                List(days, id: \.self) { day in Button { selectedDay = day } label: { Label(day.formatted(date: .long, time: .omitted), systemImage: "calendar") } }
                    .navigationTitle("\(year)年 · \(month)月")
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回") { selectedMonth = nil } } }
            } else if let year = selectedYear {
                List(months, id: \.self) { month in Button { selectedMonth = month } label: { Label("\(month)月", systemImage: "calendar") } }
                    .navigationTitle("\(year)年")
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回") { selectedYear = nil } } }
            } else {
                List {
                    ForEach(years, id: \.self) { year in Button { selectedYear = year } label: { Label("\(year)年", systemImage: "books.vertical") } }
                    if entries.isEmpty { ContentUnavailableView("还没有照片", systemImage: "photo.on.rectangle.angled", description: Text("从本地选择照片，照片只会复制到 App 私有空间。")) }
                }.navigationTitle("我的相册")
            }
        }.onChange(of: selectedItem) { _, item in Task { await importPhoto(item) } }
    }
    @MainActor private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.94) else { return }
        do { let name = try LocalFileStore.save(jpeg, in: .photos); context.insert(PhotoEntry(photoFileName: name)) }
        catch { print("Photo import failed: \(error)") }
        selectedItem = nil
    }
}

private struct DayAlbumView: View {
    let day: Date
    let mode: AlbumHomeView.BrowseMode
    let entries: [PhotoEntry]
    let onBack: () -> Void
    var body: some View {
        VStack {
            HStack { Button("返回日期", action: onBack); Spacer(); Text(day.formatted(date: .complete, time: .omitted)).font(.headline) }.padding(.horizontal)
            if mode == .scroll {
                ScrollView { LazyVStack(spacing: 22) { ForEach(entries) { PhotoPageView(entry: $0) } }.padding() }
            } else {
                TabView { ForEach(entries) { PhotoPageView(entry: $0).padding() } }.tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
    }
}
private struct PhotoPageView: View {
    @Bindable var entry: PhotoEntry
    var body: some View {
        VStack(spacing: 12) {
            if let url = LocalFileStore.url(entry.photoFileName, in: .photos), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().padding(12).background(.pink.opacity(0.07), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.pink.opacity(0.35), lineWidth: 2))
            }
            DatePicker("照片日期", selection: $entry.customDate, displayedComponents: .date)
            TextField("写下当时的想法…", text: $entry.thought, axis: .vertical).textFieldStyle(.roundedBorder)
            NavigationLink("贴纸 DIY") { StickerEditorView(entry: entry) }.buttonStyle(.borderedProminent)
        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
    }
}
