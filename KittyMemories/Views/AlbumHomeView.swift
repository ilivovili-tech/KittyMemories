import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AlbumHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PhotoEntry.customDate, order: .reverse) private var entries: [PhotoEntry]
    @State private var selectedItem: PhotosPickerItem?
    @AppStorage("albumBrowseMode") private var modeRaw = BrowseMode.book.rawValue
    @State private var selectedYear: Int?
    @State private var selectedMonth: Int?
    @State private var selectedDay: Date?
    @State private var importError: String?
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
                Picker("浏览模式", selection: $modeRaw) { ForEach(BrowseMode.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) } }.pickerStyle(.segmented)
                PhotosPicker(selection: $selectedItem, matching: .images) { Image(systemName: "plus").font(.title3).padding(11).glassEffect(.regular, in: .circle) }
            }.padding(.horizontal)
            if let day = selectedDay {
                DayAlbumView(day: day, mode: BrowseMode(rawValue: modeRaw) ?? .book, entries: entries.filter { Calendar.current.isDate($0.customDate, inSameDayAs: day) }, onBack: { selectedDay = nil })
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
        }
        .onChange(of: selectedItem) { _, item in Task { await importPhoto(item) } }
        .alert("无法导入照片", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "请稍后重试。")
        }
    }
    @MainActor private func importPhoto(_ item: PhotosPickerItem?) async {
        defer { selectedItem = nil }
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.94) else {
                importError = "无法读取所选照片，请换一张图片重试。"
                return
            }
            let name = try LocalFileStore.save(jpeg, in: .photos)
            do {
                context.insert(PhotoEntry(photoFileName: name))
                try context.save()
            } catch {
                LocalFileStore.delete(name, from: .photos)
                throw error
            }
        } catch {
            importError = error.localizedDescription
        }
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
                PaperFlipAlbumView(entries: entries)
            }
        }
    }
}
private struct PaperFlipAlbumView: View {
    let entries: [PhotoEntry]
    @State private var page = 0
    @State private var drag: CGFloat = 0
    @State private var isFlipping = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.94, green: 0.90, blue: 0.81))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
                if entries.indices.contains(page) {
                    PhotoPageView(entry: entries[page])
                        .padding(8)
                        .background(Color(red: 0.99, green: 0.97, blue: 0.91))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(.black.opacity(0.08)).frame(width: 5).blur(radius: 2)
                        }
                        .rotation3DEffect(
                            .degrees(Double(-drag / max(proxy.size.width, 1)) * 48),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: drag < 0 ? .leading : .trailing,
                            perspective: 0.55
                        )
                        .offset(x: drag * 0.12)
                        .shadow(color: .black.opacity(abs(drag) / max(proxy.size.width, 1) * 0.22),
                                radius: 12, x: drag * 0.04, y: 4)
                }
                VStack {
                    Spacer()
                    HStack {
                        Button { flip(-1) } label: { Image(systemName: "chevron.left") }
                            .disabled(page == 0 || isFlipping)
                        Spacer()
                        Text("\(entries.isEmpty ? 0 : page + 1) / \(entries.count)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button { flip(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(page >= entries.count - 1 || isFlipping)
                    }.buttonStyle(.plain).padding(.horizontal, 18).padding(.vertical, 12)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard !isFlipping else { return }
                    drag = min(proxy.size.width * 0.75, max(-proxy.size.width * 0.75, value.translation.width))
                }
                .onEnded { value in
                    let threshold = proxy.size.width * 0.18
                    if value.translation.width < -threshold { flip(1) }
                    else if value.translation.width > threshold { flip(-1) }
                    else { withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { drag = 0 } }
                })
        }
    }

    private func flip(_ direction: Int) {
        let target = page + direction
        guard entries.indices.contains(target), !isFlipping else { return }
        isFlipping = true
        withAnimation(.easeIn(duration: 0.16)) {
            drag = direction > 0 ? -180 : 180
        } completion: {
            page = target
            drag = direction > 0 ? 180 : -180
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                drag = 0
            } completion: {
                isFlipping = false
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
