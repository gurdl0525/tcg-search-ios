import SwiftUI

struct SessionSummaryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var session: AuthSession

    @State private var selectedTab = CardSearchTab.home
    @State private var searchText = ""
    @State private var selectedLanguage = CardLanguage.all
    @State private var selectedSort = CardSort.cardNumberDescending
    @State private var selectedTypes: Set<CardType> = []
    @State private var selectedRarities: Set<CardRarity> = []
    @State private var selectedDetails: Set<CardDetailCondition> = []
    @State private var selectedPack = CardPack.all
    @State private var illustrator = ""
    @State private var character = ""
    @State private var isShowingFilter = false
    @State private var isShowingSearchResults = false
    @State private var isShowingLoadingPreview = false

    private var theme: CardSearchTheme {
        CardSearchTheme(colorScheme: colorScheme)
    }

    private var visibleCards: [CardSearchPreview] {
        let cards = CardSearchPreview.samples
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return cards
        }

        return cards.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
                $0.cardNumber.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CardSearchBackground(theme: theme)
                .ignoresSafeArea()

            currentTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CardSearchBottomNavigator(selectedTab: $selectedTab, theme: theme)
                .padding(.bottom, CardSearchMetrics.navBottomPadding)
                .zIndex(1)

            if isShowingFilter {
                filterOverlay
                    .zIndex(2)
            }
        }
        .animation(CardSearchMotion.filterSheet, value: isShowingFilter)
        .animation(.easeOut(duration: 0.18), value: selectedTab)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .home:
            if isShowingSearchResults {
                CardSearchResultsView(
                    searchText: $searchText,
                    selectedLanguage: $selectedLanguage,
                    selectedSort: $selectedSort,
                    isShowingLoadingPreview: $isShowingLoadingPreview,
                    isShowingFilter: $isShowingFilter,
                    cards: visibleCards,
                    theme: theme,
                    close: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isShowingSearchResults = false
                        }
                    },
                )
            } else {
                CardSearchHomeView(
                    searchText: $searchText,
                    selectedLanguage: $selectedLanguage,
                    cards: CardSearchPreview.samples,
                    theme: theme,
                    startSearch: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isShowingSearchResults = true
                        }
                    },
                    showFilter: {
                        withAnimation(CardSearchMotion.filterSheet) {
                            isShowingFilter = true
                        }
                    },
                )
            }
        case .collection:
            CardCollectionPlaceholder(theme: theme)
        case .deck:
            CardDeckPlaceholder(theme: theme)
        case .settings:
            CardSearchSettingsView(theme: theme) {
                Task { await session.logout() }
            }
        }
    }

    private var filterOverlay: some View {
        ZStack(alignment: .bottom) {
            theme.filterScrim
                .ignoresSafeArea()
                .transition(.opacity.animation(CardSearchMotion.filterScrim))
                .onTapGesture {
                    withAnimation(CardSearchMotion.filterSheet) {
                        isShowingFilter = false
                    }
                }

            CardSearchFilterSheet(
                selectedLanguage: $selectedLanguage,
                selectedTypes: $selectedTypes,
                selectedRarities: $selectedRarities,
                selectedDetails: $selectedDetails,
                selectedPack: $selectedPack,
                illustrator: $illustrator,
                character: $character,
                theme: theme,
                applyFilters: {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedTab = .home
                        isShowingSearchResults = true
                    }
                },
                close: {
                    withAnimation(CardSearchMotion.filterSheet) {
                        isShowingFilter = false
                    }
                },
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity),
            ))
        }
    }
}

private struct CardSearchHomeView: View {
    @Binding var searchText: String
    @Binding var selectedLanguage: CardLanguage

    let cards: [CardSearchPreview]
    let theme: CardSearchTheme
    let startSearch: () -> Void
    let showFilter: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SearchField(
                    text: $searchText,
                    placeholder: "나미, OP01-016",
                    theme: theme,
                    onSubmit: startSearch,
                    filterAction: showFilter,
                )
                .padding(.top, 64)

                LanguageChipRow(selectedLanguage: $selectedLanguage, theme: theme)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SectionTitle("최근 많이 찾는 카드", theme: theme)

                        Spacer()

                        Text("\(cards.count) cards")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                    }

                    LazyVStack(spacing: 16) {
                        ForEach(cards.prefix(3)) { card in
                            HomeCardRow(card: card, theme: theme)
                        }
                    }
                }
            }
            .padding(.horizontal, CardSearchMetrics.screenHorizontalPadding)
            .padding(.bottom, 96)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct CardSearchResultsView: View {
    @Binding var searchText: String
    @Binding var selectedLanguage: CardLanguage
    @Binding var selectedSort: CardSort
    @Binding var isShowingLoadingPreview: Bool
    @Binding var isShowingFilter: Bool

    let cards: [CardSearchPreview]
    let theme: CardSearchTheme
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                SearchField(
                    text: $searchText,
                    placeholder: "카드명 또는 카드 번호",
                    theme: theme,
                    onSubmit: {},
                    filterAction: {
                        withAnimation(CardSearchMotion.filterSheet) {
                            isShowingFilter = true
                        }
                    },
                )

                LanguageChipRow(selectedLanguage: $selectedLanguage, theme: theme)

                resultControls

                if isShowingLoadingPreview {
                    CardSearchLoadingState(theme: theme)
                } else if cards.isEmpty {
                    CardSearchEmptyState(theme: theme)
                } else {
                    ResponsiveCardGrid(cards: cards, theme: theme)
                }
            }
            .padding(.horizontal, CardSearchMetrics.screenHorizontalPadding)
            .padding(.bottom, 96)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("검색 결과")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text("\(cards.count) cards")
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.top, 52)
    }

    private var resultControls: some View {
        HStack(spacing: 8) {
            Text("정렬")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 42, height: 38, alignment: .leading)

            Menu {
                ForEach(CardSort.allCases) { sort in
                    Button {
                        selectedSort = sort
                    } label: {
                        Label(sort.title, systemImage: selectedSort == sort ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedSort.title)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("변경")
                        .foregroundStyle(theme.accent)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textSecondary)
                }
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .glassSurface(theme: theme, cornerRadius: 19, interactive: true)
        }
    }
}

private struct CardSearchFilterSheet: View {
    @Binding var selectedLanguage: CardLanguage
    @Binding var selectedTypes: Set<CardType>
    @Binding var selectedRarities: Set<CardRarity>
    @Binding var selectedDetails: Set<CardDetailCondition>
    @Binding var selectedPack: CardPack
    @Binding var illustrator: String
    @Binding var character: String

    let theme: CardSearchTheme
    let applyFilters: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(theme.textTertiary.opacity(0.42))
                .frame(width: 61, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            HStack {
                Text("필터")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Button("초기화", action: resetFilters)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .frame(height: 30)
            .padding(.top, 23)

            ScrollView {
                filterContent
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .padding(.top, 18)

            Button {
                applyFilters()
                close()
            } label: {
                Text("필터 적용")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.accent)
                    }
                    .shadow(color: theme.accent.opacity(theme.isBlack ? 0.22 : 0.16), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .frame(height: CardSearchMetrics.filterSheetHeight)
        .glassSurface(theme: theme, cornerRadius: 34, style: .sheet)
    }

    private var filterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilterSection(title: "언어", theme: theme) {
                WrapChips(verticalSpacing: 6) {
                    ForEach(CardLanguage.allCases) { language in
                        filterChip(
                            title: language.title,
                            isSelected: selectedLanguage == language,
                        ) {
                            selectedLanguage = language
                        }
                    }
                }
            }

            FilterSection(title: "카드 타입", theme: theme) {
                WrapChips(verticalSpacing: 6) {
                    ForEach(CardType.allCases) { type in
                        filterChip(
                            title: type.title,
                            isSelected: selectedTypes.contains(type),
                        ) {
                            selectedTypes.toggle(type)
                        }
                    }
                }
            }
            .padding(.top, 12)

            FilterSection(title: "레어도", theme: theme) {
                WrapChips(verticalSpacing: 6) {
                    ForEach(CardRarity.allCases) { rarity in
                        filterChip(
                            title: rarity.rawValue,
                            isSelected: selectedRarities.contains(rarity),
                        ) {
                            selectedRarities.toggle(rarity)
                        }
                    }
                }
            }
            .padding(.top, 14)

            FilterSection(title: "세부 조건", theme: theme) {
                WrapChips(verticalSpacing: 6) {
                    ForEach(CardDetailCondition.allCases) { detail in
                        filterChip(
                            title: detail.title,
                            isSelected: selectedDetails.contains(detail),
                        ) {
                            selectedDetails.toggle(detail)
                        }
                    }
                }
            }
            .padding(.top, 14)

            FilterSection(title: "팩", theme: theme, titleStyle: .muted, contentSpacing: 6) {
                FilterPackSelect(selectedPack: $selectedPack, theme: theme)
            }
            .padding(.top, 14)

            HStack(alignment: .top, spacing: 18) {
                FilterTextField(
                    title: "일러스트레이터",
                    text: $illustrator,
                    placeholder: "작가명 검색",
                    trailingSystemName: "magnifyingglass",
                    theme: theme,
                )

                FilterTextField(
                    title: "등장인물",
                    text: $character,
                    placeholder: "캐릭터 선택",
                    trailingSystemName: "chevron.down",
                    theme: theme,
                )
            }
            .padding(.top, 18)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        SelectableChip(
            title: title,
            isSelected: isSelected,
            theme: theme,
            font: .system(size: 11, weight: .medium),
            horizontalPadding: 13,
            height: CardSearchMetrics.filterChipHeight,
            minWidth: filterChipWidth(for: title),
            action: action,
        )
    }

    private func filterChipWidth(for title: String) -> CGFloat {
        switch title {
        case "C", "R":
            return 42
        case "UC", "SR", "TR", "SP":
            return 46
        case "SEC", "전체", "한글", "영어", "리더", "망가":
            return title == "SEC" ? 54 : 56
        case "일본어", "두웅!!":
            return 68
        case "캐릭터", "이벤트", "프로모":
            return 70
        case "스테이지":
            return 78
        case "Parallel":
            return 82
        default:
            return 56
        }
    }

    private func resetFilters() {
        selectedLanguage = .all
        selectedTypes.removeAll()
        selectedRarities.removeAll()
        selectedDetails.removeAll()
        selectedPack = .all
        illustrator = ""
        character = ""
    }
}

private struct CardSearchEmptyState: View {
    let theme: CardSearchTheme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 108, height: 108)
                .glassSurface(theme: theme, cornerRadius: 34)

            Text("검색 결과가 없어요")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            Text("검색어를 줄이거나 필터 조건을 다시 확인해 주세요.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(width: 277)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }
}

private struct CardSearchLoadingState: View {
    let theme: CardSearchTheme

    var body: some View {
        ResponsiveSkeletonGrid(theme: theme)
    }
}

private struct CardSearchBottomNavigator: View {
    @Binding var selectedTab: CardSearchTab

    let theme: CardSearchTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CardSearchMetrics.navBarHeight / 2, style: .continuous)
                .fill(.clear)
                .frame(maxWidth: CardSearchMetrics.navBarWidth)
                .frame(height: CardSearchMetrics.navBarHeight)
                .glassSurface(theme: theme, cornerRadius: CardSearchMetrics.navBarHeight / 2, style: .navigationBar)

            HStack(spacing: CardSearchMetrics.navItemSpacing) {
                ForEach(CardSearchTab.allCases) { tab in
                    CardSearchNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        theme: theme,
                    ) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .frame(width: CardSearchMetrics.navContentWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
    }
}

private struct CardSearchNavItem: View {
    let tab: CardSearchTab
    let isSelected: Bool
    let theme: CardSearchTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.clear)
                        .frame(width: 62, height: 54)
                        .glassSurface(theme: theme, cornerRadius: 22, interactive: true, style: .navigationActive)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                VStack(spacing: 4) {
                    Image(systemName: isSelected ? tab.selectedSymbol : tab.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 22, height: 22)

                    Text(tab.title)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: 70, height: 14)
                }
                .foregroundStyle(isSelected ? theme.navActiveForeground : theme.navInactiveForeground)
                .opacity(isSelected ? 1 : theme.navInactiveOpacity)
                .frame(width: 70, height: 54)
            }
            .frame(width: 70, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ResponsiveCardGrid: View {
    let cards: [CardSearchPreview]
    let theme: CardSearchTheme

    var body: some View {
        GeometryReader { proxy in
            let layout = CardGrid.layout(for: proxy.size.width)

            LazyVGrid(columns: layout.columns, spacing: 14) {
                ForEach(cards) { card in
                    CardPreviewTile(card: card, theme: theme, cardWidth: layout.cardWidth)
                }
            }
        }
        .frame(height: CardGrid.height(itemCount: cards.count, availableWidth: CardSearchMetrics.contentWidth))
    }
}

private struct ResponsiveSkeletonGrid: View {
    let theme: CardSearchTheme

    var body: some View {
        GeometryReader { proxy in
            let layout = CardGrid.layout(for: proxy.size.width)

            LazyVGrid(columns: layout.columns, spacing: 14) {
                ForEach(0 ..< 4, id: \.self) { index in
                    let artWidth = CardSearchMetrics.resultArtWidth(forCardWidth: layout.cardWidth)
                    let artHeight = CardSearchMetrics.resultArtHeight(forArtWidth: artWidth)

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.skeletonFill)
                            .frame(width: artWidth, height: artHeight)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.skeletonFill)
                            .frame(width: min(76, artWidth * 0.55), height: 10)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.skeletonFill)
                            .frame(width: min(index.isMultiple(of: 2) ? 112 : 96, artWidth * 0.84), height: 12)
                    }
                    .padding(CardSearchMetrics.resultArtInset)
                    .frame(
                        width: layout.cardWidth,
                        height: CardSearchMetrics.resultCardHeight(forCardWidth: layout.cardWidth),
                    )
                    .glassSurface(theme: theme, cornerRadius: 22)
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(height: CardGrid.height(itemCount: 4, availableWidth: CardSearchMetrics.contentWidth))
    }
}

private struct CardCollectionPlaceholder: View {
    let theme: CardSearchTheme

    var body: some View {
        ContentUnavailableView {
            Label("컬렉션", systemImage: "rectangle.stack")
                .foregroundStyle(theme.textPrimary)
        } description: {
            Text("수집 목록 화면은 다음 단계에서 연결합니다.")
        }
        .foregroundStyle(theme.textSecondary)
        .background(CardSearchBackground(theme: theme).ignoresSafeArea())
    }
}

private struct CardDeckPlaceholder: View {
    let theme: CardSearchTheme

    var body: some View {
        ContentUnavailableView {
            Label("덱", systemImage: "rectangle.on.rectangle.angled")
                .foregroundStyle(theme.textPrimary)
        } description: {
            Text("덱 빌딩 화면은 다음 단계에서 연결합니다.")
        }
        .foregroundStyle(theme.textSecondary)
        .background(CardSearchBackground(theme: theme).ignoresSafeArea())
    }
}

private struct CardSearchSettingsView: View {
    let theme: CardSearchTheme
    let logout: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "gearshape")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 58, height: 58)
                .glassSurface(theme: theme, cornerRadius: 22)

            Button(role: .destructive, action: logout) {
                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .padding(.horizontal, 22)
            .glassSurface(theme: theme, cornerRadius: 18, interactive: true)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CardSearchBackground(theme: theme).ignoresSafeArea())
    }
}

private struct CardPreviewTile: View {
    let card: CardSearchPreview
    let theme: CardSearchTheme
    let cardWidth: CGFloat

    var body: some View {
        let outerInset = CardSearchMetrics.resultArtInset
        let infoInset = CardSearchMetrics.resultInfoInset
        let artWidth = CardSearchMetrics.resultArtWidth(forCardWidth: cardWidth)
        let artHeight = CardSearchMetrics.resultArtHeight(forArtWidth: artWidth)

        VStack(alignment: .leading, spacing: CardSearchMetrics.resultArtInfoSpacing) {
            CardArtwork(
                card: card,
                theme: theme,
                width: artWidth,
                height: artHeight,
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(card.cardNumber)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Spacer(minLength: 3)

                    Text(card.language)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.accentLabel)
                        .frame(width: 30, height: 18)
                        .background(theme.accentSurface, in: Capsule())
                }

                Text(card.compactResultName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(card.compactResultMeta)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, infoInset)
            .padding(.vertical, 5)
            .frame(width: artWidth, height: CardSearchMetrics.resultInfoHeight, alignment: .topLeading)
            .glassSurface(theme: theme, cornerRadius: 16, style: .inner)
        }
        .padding(outerInset)
        .frame(width: cardWidth, height: CardSearchMetrics.resultCardHeight(forCardWidth: cardWidth))
        .glassSurface(theme: theme, cornerRadius: 22)
    }
}

private struct HomeCardRow: View {
    let card: CardSearchPreview
    let theme: CardSearchTheme

    var body: some View {
        HStack(spacing: 14) {
            CardArtwork(
                card: card,
                theme: theme,
                width: CardSearchMetrics.homeThumbWidth,
                height: CardSearchMetrics.homeThumbHeight,
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(card.cardNumber)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.accent)

                Text(card.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(card.meta)
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                Text(card.trait)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .frame(height: CardSearchMetrics.homeRowHeight)
        .glassSurface(theme: theme, cornerRadius: 24)
    }
}

private struct CardArtwork: View {
    let card: CardSearchPreview
    let theme: CardSearchTheme
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            if let imageName = card.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card.gradient)

                VStack(spacing: 8) {
                    Image(systemName: card.symbol)
                        .font(.system(size: 34, weight: .bold))
                        .symbolRenderingMode(.hierarchical)

                    Text(card.type)
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: card.shadowColor.opacity(theme.isBlack ? 0.36 : 0.18), radius: 18, x: 0, y: 14)
    }
}

private struct SearchField: View {
    @Binding var text: String

    let placeholder: String
    let theme: CardSearchTheme
    let onSubmit: () -> Void
    var filterAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.searchControlIcon)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(theme.textPrimary)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }

            if let filterAction {
                Button(action: filterAction) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.searchControlIcon)
                        .frame(width: 32, height: 32)
                        .glassSurface(theme: theme, cornerRadius: 16, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("필터")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 52)
        .glassSurface(theme: theme, cornerRadius: CardSearchMetrics.searchRadius, interactive: true)
    }
}

private struct LanguageChipRow: View {
    @Binding var selectedLanguage: CardLanguage

    let theme: CardSearchTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardLanguage.allCases) { language in
                    SelectableChip(
                        title: language.title,
                        isSelected: selectedLanguage == language,
                        theme: theme,
                        font: .system(size: 11, weight: .medium),
                        horizontalPadding: 13,
                        height: CardSearchMetrics.chipHeight,
                        minWidth: chipWidth(for: language),
                        selectedForeground: theme.accent,
                        unselectedForeground: theme.textSecondary,
                    ) {
                        selectedLanguage = language
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
        .padding(.vertical, -6)
    }

    private func chipWidth(for language: CardLanguage) -> CGFloat {
        switch language {
        case .jp:
            return 68
        default:
            return 56
        }
    }
}

private struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let theme: CardSearchTheme
    var font: Font = .subheadline.weight(.semibold)
    var horizontalPadding: CGFloat = CardSearchMetrics.chipHorizontalPadding
    var height: CGFloat = CardSearchMetrics.chipHeight
    var minWidth: CGFloat?
    var selectedForeground: Color?
    var unselectedForeground: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(isSelected ? selectedForeground ?? theme.accentStrong : unselectedForeground ?? theme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, horizontalPadding)
                .frame(minWidth: minWidth)
                .frame(height: height)
                .glassSurface(
                    theme: theme,
                    cornerRadius: height / 2,
                    interactive: true,
                    style: isSelected ? .chipSelected : .chipPlain,
                )
        }
        .buttonStyle(.plain)
    }
}

private enum FilterSectionTitleStyle: Equatable {
    case primary
    case muted
}

private struct FilterSection<Content: View>: View {
    let title: String
    let theme: CardSearchTheme
    var titleStyle: FilterSectionTitleStyle = .primary
    var contentSpacing: CGFloat = 8
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            Text(title)
                .font(.system(size: titleStyle == .primary ? 13 : 12, weight: .bold))
                .foregroundStyle(titleStyle == .primary ? theme.filterTitle : theme.filterMutedTitle)
                .lineLimit(1)

            content
        }
    }
}

private struct FilterPackSelect: View {
    @Binding var selectedPack: CardPack

    let theme: CardSearchTheme

    var body: some View {
        Menu {
            ForEach(CardPack.allCases) { pack in
                Button {
                    selectedPack = pack
                } label: {
                    Text(pack.title)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(selectedPack.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.filterControlIcon)
                    .frame(width: 18, height: 18)
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity)
            .frame(height: CardSearchMetrics.filterControlHeight)
            .filterControlSurface(theme: theme, cornerRadius: 12, fill: theme.filterPackFill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("팩 선택")
    }
}

private struct FilterTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let trailingSystemName: String
    let theme: CardSearchTheme

    var body: some View {
        FilterSection(title: title, theme: theme, contentSpacing: 6) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 12, weight: text.isEmpty ? .regular : .medium))
                    .foregroundStyle(theme.textPrimary)
                    .tint(theme.accent)
                    .lineLimit(1)

                Image(systemName: trailingSystemName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.filterControlIcon)
                    .frame(width: 20, height: 20)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity)
            .frame(height: CardSearchMetrics.filterControlHeight)
            .filterControlSurface(theme: theme, cornerRadius: 15, fill: theme.filterControlFill)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FilterShortcut: View {
    let title: String
    let subtitle: String
    let theme: CardSearchTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(theme: theme, cornerRadius: 20)
    }
}

private struct SectionTitle: View {
    let title: String
    let theme: CardSearchTheme

    init(_ title: String, theme: CardSearchTheme) {
        self.title = title
        self.theme = theme
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(theme.textPrimary)
    }
}

private struct WrapChips<Content: View>: View {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    @ViewBuilder let content: Content

    init(
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content,
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        FlowLayout(horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing) {
            content
        }
    }
}

private struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(0, rows.count - 1)) * verticalSpacing

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size),
                )
                x += size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var current = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.indices.isEmpty ? size.width : current.width + horizontalSpacing + size.width

            if nextWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = FlowRow()
            }

            current.indices.append(index)
            current.width = current.indices.count == 1 ? size.width : current.width + horizontalSpacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }
}

private struct FlowRow {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}

private struct CardSearchBackground: View {
    let theme: CardSearchTheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                theme.background

                LinearGradient(
                    stops: [
                        .init(color: theme.backgroundWashTop, location: 0),
                        .init(color: theme.background, location: 0.52),
                        .init(color: theme.backgroundWashBottom, location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                )

                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(theme.pageTopFrost)
                    .frame(width: max(width - 32, 0), height: 128)
                    .position(x: width / 2, y: 152)
                    .blur(radius: 12)

                RoundedRectangle(cornerRadius: 72, style: .continuous)
                    .fill(theme.pageContentMist)
                    .frame(width: max(width - 16, 0), height: 360)
                    .position(x: width / 2, y: 428)
                    .blur(radius: 20)

                RadialGradient(
                    colors: [theme.ambientGlow, .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 380,
                )
            }
        }
    }
}

private enum GlassSurfaceStyle {
    case surface
    case inner
    case sheet
    case chipPlain
    case chipSelected
    case navigationBar
    case navigationActive
}

private struct GlassSurfaceModifier: ViewModifier {
    let theme: CardSearchTheme
    let cornerRadius: CGFloat
    let interactive: Bool
    let style: GlassSurfaceStyle

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let shadow = theme.glassShadow(for: style)

        if #available(iOS 26.0, *) {
            content
                .background {
                    GlassSurfaceBackground(theme: theme, cornerRadius: cornerRadius, style: style)
                }
                .overlay {
                    shape.stroke(theme.glassStroke(for: style), lineWidth: 1)
                }
                .glassEffect(glassEffect, in: .rect(cornerRadius: cornerRadius))
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        } else {
            content
                .background {
                    GlassSurfaceBackground(theme: theme, cornerRadius: cornerRadius, style: style)
                }
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(theme.glassStroke(for: style), lineWidth: 1)
                }
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
    }

    @available(iOS 26.0, *)
    private var glassEffect: Glass {
        if interactive {
            return .regular.tint(theme.glassTint(for: style)).interactive()
        }

        return .regular.tint(theme.glassTint(for: style))
    }
}

private struct GlassSurfaceBackground: View {
    let theme: CardSearchTheme
    let cornerRadius: CGFloat
    let style: GlassSurfaceStyle

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let inset = detailInset(width: size.width)
            let detailWidth = max(size.width - inset * 2, 0)
            let topHeight = min(max(size.height * 0.38, 10), 28)
            let bottomHeight = min(max(size.height * 0.30, 8), 18)
            let detailRadius = max(cornerRadius - inset, 5)
            let lineWidth = specularWidth(width: size.width)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.glassFill(for: style))

                RoundedRectangle(cornerRadius: detailRadius, style: .continuous)
                    .fill(theme.glassTopVeil(for: style))
                    .frame(width: detailWidth, height: topHeight)
                    .position(x: size.width / 2, y: inset + topHeight / 2)
                    .blur(radius: 0.6)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(theme.glassSpecular(for: style))
                    .frame(width: lineWidth, height: size.width <= 48 ? 1 : 1.2)
                    .position(x: size.width / 2, y: max(inset * 0.48, 3))

                RoundedRectangle(cornerRadius: detailRadius, style: .continuous)
                    .fill(theme.glassBottomDepth(for: style))
                    .frame(width: detailWidth, height: bottomHeight)
                    .position(x: size.width / 2, y: size.height - inset - bottomHeight / 2)
                    .blur(radius: 0.8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    private func detailInset(width: CGFloat) -> CGFloat {
        if width <= 48 {
            return 7
        }

        if width <= 140 {
            return 6
        }

        return 7
    }

    private func specularWidth(width: CGFloat) -> CGFloat {
        if width <= 48 {
            return 6
        }

        return max(width - 24, 0)
    }
}

private extension View {
    func glassSurface(
        theme: CardSearchTheme,
        cornerRadius: CGFloat,
        interactive: Bool = false,
        style: GlassSurfaceStyle = .surface,
    ) -> some View {
        modifier(
            GlassSurfaceModifier(
                theme: theme,
                cornerRadius: cornerRadius,
                interactive: interactive,
                style: style,
            ),
        )
    }

    func filterControlSurface(theme: CardSearchTheme, cornerRadius: CGFloat, fill: Color) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(theme.filterControlStroke, lineWidth: 1)
        }
        .shadow(color: theme.filterControlShadow, radius: 10, x: 0, y: 5)
    }
}

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

private enum CardGrid {
    static func layout(for availableWidth: CGFloat) -> (columns: [GridItem], cardWidth: CGFloat, columnCount: Int) {
        let spacing = CardSearchMetrics.resultGridSpacing
        let minimumWidth = CardSearchMetrics.resultCardMinimumWidth
        let maximumWidth = CardSearchMetrics.resultCardMaximumWidth
        let count = min(3, max(1, Int((availableWidth + spacing) / (minimumWidth + spacing))))
        let unclampedWidth = (availableWidth - CGFloat(count - 1) * spacing) / CGFloat(count)
        let cardWidth = min(maximumWidth, max(minimumWidth, floor(unclampedWidth)))
        let columns = Array(
            repeating: GridItem(.fixed(cardWidth), spacing: spacing),
            count: count,
        )

        return (columns, cardWidth, count)
    }

    static func height(itemCount: Int, availableWidth: CGFloat) -> CGFloat {
        let layout = layout(for: availableWidth)
        let rows = CGFloat((itemCount + layout.columnCount - 1) / layout.columnCount)
        let itemHeight = CardSearchMetrics.resultCardHeight(forCardWidth: layout.cardWidth)

        return rows * itemHeight + max(0, rows - 1) * 14
    }
}

private enum CardSearchMetrics {
    static let screenHorizontalPadding: CGFloat = 24
    static let contentWidth: CGFloat = 393 - screenHorizontalPadding * 2
    static let searchHeight: CGFloat = 52
    static let searchRadius: CGFloat = 24
    static let navBarWidth: CGFloat = 357
    static let navBarHeight: CGFloat = 66
    static let navContentWidth: CGFloat = 334
    static let navItemSpacing: CGFloat = 18
    static let navBottomPadding: CGFloat = 16
    static let chipHeight: CGFloat = 30
    static let chipHorizontalPadding: CGFloat = 14
    static let filterSheetHeight: CGFloat = 658
    static let filterChipHeight: CGFloat = 30
    static let filterControlHeight: CGFloat = 40
    static let homeRowHeight: CGFloat = 132
    static let homeThumbWidth: CGFloat = 74
    static let homeThumbHeight: CGFloat = 104
    static let resultCardWidth: CGFloat = 107
    static let resultCardMinimumWidth: CGFloat = 96
    static let resultCardMaximumWidth: CGFloat = 112
    static let resultGridSpacing: CGFloat = 12
    static let resultArtInset: CGFloat = 6
    static let resultArtWidth: CGFloat = 95
    static let resultArtHeight: CGFloat = 133
    static let resultImageAspectRatio: CGFloat = 600.0 / 838.0
    static let resultInfoHeight: CGFloat = 52
    static let resultInfoInset: CGFloat = 6
    static let resultArtInfoSpacing: CGFloat = 6
    static let filterSheetTop: CGFloat = 194

    static func resultArtWidth(forCardWidth cardWidth: CGFloat) -> CGFloat {
        max(0, cardWidth - resultArtInset * 2)
    }

    static func resultArtHeight(forArtWidth artWidth: CGFloat) -> CGFloat {
        artWidth / resultImageAspectRatio
    }

    static func resultCardHeight(forCardWidth cardWidth: CGFloat) -> CGFloat {
        let artWidth = resultArtWidth(forCardWidth: cardWidth)
        return resultArtInset + resultArtHeight(forArtWidth: artWidth) + resultArtInfoSpacing + resultInfoHeight + resultArtInset
    }
}

private enum CardSearchMotion {
    static let filterSheet = Animation.spring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.08)
    static let filterScrim = Animation.easeOut(duration: 0.16)
}

private struct CardSearchTheme {
    let colorScheme: ColorScheme

    var isBlack: Bool {
        colorScheme == .dark
    }

    var background: Color {
        isBlack ? Color(hex: 0x080D0B) : Color(hex: 0xF5F7F2)
    }

    var backgroundWashTop: Color {
        isBlack ? Color(hex: 0x193C2D).opacity(0.34) : Color(hex: 0xD8F0E4).opacity(0.45)
    }

    var backgroundWashBottom: Color {
        isBlack ? Color(hex: 0x0D1512).opacity(0.86) : Color(hex: 0xE7EFE7).opacity(0.52)
    }

    var ambientGlow: Color {
        isBlack ? Color(hex: 0x1F7A57).opacity(0.18) : Color.white.opacity(0.72)
    }

    var pageTopFrost: LinearGradient {
        if isBlack {
            return LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.02), location: 0),
                    .init(color: Color(hex: 0x151F18).opacity(0.03), location: 0.58),
                    .init(color: .white.opacity(0), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }

        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0.30), location: 0),
                .init(color: Color(hex: 0xF0FCF5).opacity(0.18), location: 0.58),
                .init(color: .white.opacity(0), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    var pageContentMist: LinearGradient {
        if isBlack {
            return LinearGradient(
                stops: [
                    .init(color: Color(hex: 0xD8F0E4).opacity(0.03), location: 0),
                    .init(color: .white.opacity(0.01), location: 0.46),
                    .init(color: Color(hex: 0xD8F0E4).opacity(0), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }

        return LinearGradient(
            stops: [
                .init(color: Color(hex: 0x1F7A57).opacity(0.05), location: 0),
                .init(color: .white.opacity(0.08), location: 0.46),
                .init(color: Color(hex: 0x1F7A57).opacity(0), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    var filterScrim: Color {
        Color.black.opacity(isBlack ? 0.42 : 0.18)
    }

    var surface: Color {
        isBlack ? Color.black.opacity(0.64) : Color.white.opacity(0.64)
    }

    var surfaceStrong: Color {
        isBlack ? Color(hex: 0x0D1512).opacity(0.88) : Color(hex: 0xF9FBF7).opacity(0.88)
    }

    var innerSurface: Color {
        isBlack ? Color.black.opacity(0.24) : Color.white.opacity(0.26)
    }

    var surfaceStroke: Color {
        isBlack ? Color.white.opacity(0.12) : Color.white.opacity(0.64)
    }

    var skeletonFill: Color {
        isBlack ? Color(hex: 0x24362D).opacity(0.8) : Color(hex: 0xE1E9E1)
    }

    var imagePlaceholderA: Color {
        isBlack ? Color(hex: 0x24362D) : Color(hex: 0xDCE8DE)
    }

    var imagePlaceholderB: Color {
        isBlack ? Color(hex: 0x2E473A) : Color(hex: 0xEEF4EF)
    }

    var textPrimary: Color {
        isBlack ? Color(hex: 0xF3F8F4) : Color(hex: 0x17211B)
    }

    var textSecondary: Color {
        isBlack ? Color(hex: 0xB4C1B9) : Color(hex: 0x56635B)
    }

    var textTertiary: Color {
        isBlack ? Color(hex: 0x84918A) : Color(hex: 0x78847C)
    }

    var filterTitle: Color {
        isBlack ? Color(hex: 0xF3F8F4) : Color(hex: 0x070B09)
    }

    var filterMutedTitle: Color {
        isBlack ? Color(hex: 0xB4C1B9) : Color(hex: 0x4F6259)
    }

    var filterControlFill: Color {
        isBlack ? Color.white.opacity(0.07) : Color.white.opacity(0.66)
    }

    var filterPackFill: Color {
        isBlack ? Color.white.opacity(0.08) : Color.white.opacity(0.92)
    }

    var filterControlStroke: Color {
        isBlack ? Color.white.opacity(0.12) : Color(hex: 0xD6E1D8).opacity(0.68)
    }

    var filterControlIcon: Color {
        isBlack ? Color(hex: 0xC2D1C7).opacity(0.82) : Color(hex: 0x476454).opacity(0.82)
    }

    var searchControlIcon: Color {
        isBlack ? Color(hex: 0xC2D1C7).opacity(0.82) : Color(hex: 0x48627A)
    }

    var filterControlShadow: Color {
        .black.opacity(isBlack ? 0.18 : 0.025)
    }

    var accent: Color {
        isBlack ? Color(hex: 0x1F7A57) : Color(hex: 0x248A62)
    }

    var accentStrong: Color {
        Color(hex: 0x1F7A57)
    }

    var accentLabel: Color {
        isBlack ? Color(hex: 0xD7F1E5) : Color(hex: 0x145C41)
    }

    var accentSurface: Color {
        isBlack ? Color(hex: 0x193C2D) : Color(hex: 0xD8F0E4)
    }

    var accentStroke: Color {
        isBlack ? Color(hex: 0x2B5A45) : Color(hex: 0xB9DDCD)
    }

    var navActiveForeground: Color {
        isBlack ? Color(hex: 0xD8F0E4) : accentStrong
    }

    var navInactiveForeground: Color {
        isBlack ? Color(hex: 0xC2D1C7) : Color(hex: 0x5C6B62)
    }

    var navInactiveOpacity: Double {
        isBlack ? 0.88 : 0.82
    }

    func glassFill(for style: GlassSurfaceStyle) -> Color {
        switch style {
        case .surface:
            return surface
        case .inner:
            return innerSurface
        case .sheet:
            return surfaceStrong
        case .chipPlain:
            return isBlack ? Color.white.opacity(0.06) : Color.white.opacity(0.56)
        case .chipSelected:
            return isBlack ? Color(hex: 0x193C2D).opacity(0.88) : Color(hex: 0xD8F0E4).opacity(0.96)
        case .navigationBar:
            return isBlack ? Color(hex: 0x0C120F).opacity(0.88) : Color.white.opacity(0.66)
        case .navigationActive:
            return isBlack ? Color(hex: 0x193C2D).opacity(0.88) : Color(hex: 0xD8F0E4).opacity(0.82)
        }
    }

    func glassStroke(for style: GlassSurfaceStyle) -> Color {
        switch style {
        case .inner:
            return isBlack ? Color.white.opacity(0.10) : Color.white.opacity(0.28)
        case .chipSelected:
            return isBlack ? Color(hex: 0xD8F0E4).opacity(0.46) : Color(hex: 0xB9DDCD).opacity(0.92)
        case .chipPlain:
            return isBlack ? Color.white.opacity(0.12) : Color(hex: 0xD6E1D8).opacity(0.66)
        case .navigationBar:
            return isBlack ? Color(hex: 0x2A3931).opacity(0.96) : Color.white.opacity(0.94)
        case .navigationActive:
            return isBlack ? Color(hex: 0xD8F0E4).opacity(0.46) : Color(hex: 0x1F7A57).opacity(0.38)
        case .sheet:
            return isBlack ? Color(hex: 0x2A3931).opacity(0.96) : Color(hex: 0xE2E9E2).opacity(0.74)
        case .surface:
            return surfaceStroke
        }
    }

    func glassTopVeil(for style: GlassSurfaceStyle) -> Color {
        switch style {
        case .navigationBar:
            return isBlack ? Color.white.opacity(0.05) : Color.white.opacity(0.36)
        case .navigationActive:
            return isBlack ? Color.white.opacity(0.06) : Color.white.opacity(0.26)
        default:
            return isBlack ? Color.white.opacity(0.05) : Color.white.opacity(0.22)
        }
    }

    func glassSpecular(for style: GlassSurfaceStyle) -> Color {
        switch style {
        case .navigationBar:
            return isBlack ? Color(hex: 0x2A3931).opacity(0.52) : Color.white.opacity(0.88)
        case .navigationActive:
            return isBlack ? Color.white.opacity(0.18) : Color.white.opacity(0.52)
        default:
            return isBlack ? Color.white.opacity(0.10) : Color.white.opacity(0.46)
        }
    }

    func glassBottomDepth(for style: GlassSurfaceStyle) -> Color {
        switch style {
        case .navigationBar:
            return isBlack ? Color.black.opacity(0.14) : Color.white.opacity(0.12)
        case .navigationActive:
            return isBlack ? Color.black.opacity(0.14) : Color.white.opacity(0.10)
        default:
            return isBlack ? Color.black.opacity(0.08) : Color(hex: 0xF0FCF5).opacity(0.11)
        }
    }

    func glassTint(for style: GlassSurfaceStyle) -> Color {
        switch style {
        case .chipSelected, .navigationActive:
            return accentSurface.opacity(isBlack ? 0.18 : 0.22)
        case .navigationBar:
            return glassFill(for: style).opacity(0.22)
        default:
            return surface.opacity(0.18)
        }
    }

    func glassShadow(for style: GlassSurfaceStyle) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch style {
        case .inner:
            return (.clear, 0, 0, 0)
        case .chipPlain, .chipSelected:
            return (.black.opacity(isBlack ? 0.10 : 0.045), 8, 0, 3)
        case .navigationBar:
            return (.black.opacity(isBlack ? 0.28 : 0.10), isBlack ? 30 : 26, 0, isBlack ? 16 : 14)
        case .navigationActive:
            return (accentStrong.opacity(isBlack ? 0.20 : 0.12), 14, 0, 7)
        case .sheet:
            return (.black.opacity(isBlack ? 0.34 : 0.09), 28, 0, -8)
        case .surface:
            return (.black.opacity(isBlack ? 0.22 : 0.08), 20, 0, 10)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
        )
    }
}

private enum CardSearchTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case collection
    case deck
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "홈"
        case .collection:
            return "컬렉션"
        case .deck:
            return "덱"
        case .settings:
            return "설정"
        }
    }

    var symbol: String {
        switch self {
        case .home:
            return "house"
        case .collection:
            return "rectangle.stack"
        case .deck:
            return "rectangle.on.rectangle.angled"
        case .settings:
            return "gearshape"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home:
            return "house.fill"
        case .collection:
            return "rectangle.stack.fill"
        case .deck:
            return "rectangle.on.rectangle.angled.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

private enum CardLanguage: String, CaseIterable, Identifiable {
    case all
    case ko
    case en
    case jp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "전체"
        case .ko:
            return "한글"
        case .en:
            return "영어"
        case .jp:
            return "일본어"
        }
    }
}

private enum CardSort: CaseIterable, Identifiable {
    case cardNumberDescending
    case cardNumberAscending
    case nameAscending
    case nameDescending

    var id: String { title }

    var title: String {
        switch self {
        case .cardNumberDescending:
            return "카드 번호 내림차순"
        case .cardNumberAscending:
            return "카드 번호 오름차순"
        case .nameAscending:
            return "이름 오름차순"
        case .nameDescending:
            return "이름 내림차순"
        }
    }
}

private enum CardType: CaseIterable, Identifiable {
    case character
    case leader
    case don
    case event
    case stage

    var id: String { title }

    var title: String {
        switch self {
        case .character:
            return "캐릭터"
        case .leader:
            return "리더"
        case .don:
            return "두웅!!"
        case .event:
            return "이벤트"
        case .stage:
            return "스테이지"
        }
    }
}

private enum CardRarity: String, CaseIterable, Identifiable {
    case c = "C"
    case uc = "UC"
    case r = "R"
    case sr = "SR"
    case sec = "SEC"
    case tr = "TR"

    var id: String { rawValue }
}

private enum CardDetailCondition: CaseIterable, Identifiable {
    case sp
    case parallel
    case manga
    case promo

    var id: String { title }

    var title: String {
        switch self {
        case .sp:
            return "SP"
        case .parallel:
            return "Parallel"
        case .manga:
            return "망가"
        case .promo:
            return "프로모"
        }
    }
}

private enum CardPack: CaseIterable, Identifiable {
    case all
    case heroines
    case op17
    case op16
    case eb02

    var id: String { title }

    var title: String {
        switch self {
        case .all:
            return "전체"
        case .heroines:
            return "엑스트라 부스터3 히로인즈 에디션"
        case .op17:
            return "OP 17"
        case .op16:
            return "OP 16"
        case .eb02:
            return "EB 02"
        }
    }
}

private struct CardSearchPreview: Identifiable {
    let id: String
    let cardNumber: String
    let name: String
    let type: String
    let rarity: String
    let language: String
    let meta: String
    let trait: String
    let imageName: String?
    let symbol: String
    let gradient: LinearGradient
    let shadowColor: Color

    var compactResultName: String {
        switch id {
        case "st30-017-jp", "st30-017-en-p1":
            return "And You Get..."
        case "st30-016-en", "st30-016-jp-p1":
            return "Can You Fight..."
        default:
            return name
        }
    }

    var compactResultMeta: String {
        if meta.localizedCaseInsensitiveContains("Parallel") {
            return "\(rarity) · Parallel"
        }

        if meta.localizedCaseInsensitiveContains("Event") {
            return "\(rarity) · Event"
        }

        return "\(rarity) · \(type)"
    }

    static let samples: [CardSearchPreview] = [
        CardSearchPreview(
            id: "st30-017-jp",
            cardNumber: "ST30-017",
            name: "And You Get Yourself...",
            type: "EVENT",
            rarity: "C",
            language: "JP",
            meta: "C · Event · Red",
            trait: "Luffy & Ace",
            imageName: "ST30-017-jp",
            symbol: "sparkles",
            gradient: LinearGradient(colors: [Color(hex: 0xA83628), Color(hex: 0xE7A363)], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: Color(hex: 0xA83628),
        ),
        CardSearchPreview(
            id: "st30-017-en-p1",
            cardNumber: "ST30-017",
            name: "And You Get Yourself...",
            type: "EVENT",
            rarity: "C",
            language: "EN",
            meta: "C · Event · Parallel",
            trait: "Luffy & Ace",
            imageName: "ST30-017-en-p1",
            symbol: "moon.stars.fill",
            gradient: LinearGradient(colors: [Color(hex: 0xA83628), Color(hex: 0xE7A363)], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: Color(hex: 0xA83628),
        ),
        CardSearchPreview(
            id: "st30-016-en",
            cardNumber: "ST30-016",
            name: "Can You Still Fight...",
            type: "EVENT",
            rarity: "C",
            language: "EN",
            meta: "C · Event · Red",
            trait: "Luffy & Ace",
            imageName: "ST30-016-en",
            symbol: "bolt.fill",
            gradient: LinearGradient(colors: [Color(hex: 0xA83628), Color(hex: 0xE7A363)], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: Color(hex: 0xA83628),
        ),
        CardSearchPreview(
            id: "st30-016-jp-p1",
            cardNumber: "ST30-016",
            name: "Can You Still Fight...",
            type: "EVENT",
            rarity: "C",
            language: "JP",
            meta: "C · Event · Parallel",
            trait: "Luffy & Ace",
            imageName: "ST30-016-jp-p1",
            symbol: "bolt.fill",
            gradient: LinearGradient(colors: [Color(hex: 0xA83628), Color(hex: 0xE7A363)], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: Color(hex: 0xA83628),
        ),
        CardSearchPreview(
            id: "op02-001",
            cardNumber: "OP02-001",
            name: "포트거스 D. 에이스",
            type: "Character",
            rarity: "SR",
            language: "JP",
            meta: "빨강 · Whitebeard Pirates",
            trait: "Whitebeard Pirates",
            imageName: nil,
            symbol: "flame.fill",
            gradient: LinearGradient(colors: [Color(hex: 0x8A5142), Color(hex: 0xD28A5F)], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: Color(hex: 0x8A5142),
        ),
        CardSearchPreview(
            id: "op06-118",
            cardNumber: "OP06-118",
            name: "로로노아 조로",
            type: "Character",
            rarity: "SEC",
            language: "EN",
            meta: "초록 · Swordsman",
            trait: "Swordsman",
            imageName: nil,
            symbol: "bolt.fill",
            gradient: LinearGradient(colors: [Color(hex: 0x44644D), Color(hex: 0x95AF7A)], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: Color(hex: 0x44644D),
        ),
    ]
}
