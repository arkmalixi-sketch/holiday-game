import SwiftUI
import Combine

// --- 1. DATA MODELS ---
struct Player: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var tileIndex: Int
    var colorIndex: Int
    var finishRank: Int? // 1st, 2nd, 3rd...
    var lifetimeCoins: Int // For Leaderboard
    var spendableCoins: Int // For Movement
}

struct BonusItem: Identifiable, Codable {
    var id = UUID()
    var tileIndex: Int
    var type: String // "POINTS", "SHIRT", "TRAP", "SPIN", "GOLD", "CUSTOM"
    var isClaimed: Bool
    // Custom Fields
    var customTitle: String?
    var customMsg: String?
}

// --- 2. WEBSOCKET MANAGER ---
class StreamerBotClient: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    @Published var isConnected = false
    @Published var lastEvent: StreamEvent?
    
    struct StreamEvent: Decodable, Equatable {
        let event: EventSource
        let data: EventData
        
        static func == (lhs: StreamEvent, rhs: StreamEvent) -> Bool {
            return lhs.data.user.name == rhs.data.user.name && lhs.data.gift.name == rhs.data.gift.name
        }
    }
    struct EventSource: Decodable { let source: String; let type: String }
    struct EventData: Decodable { let user: UserData; let gift: GiftData }
    struct UserData: Decodable { let name: String }
    struct GiftData: Decodable { let name: String; let count: Int; let coins: Int? }

    func connect(ip: String, port: String) {
        disconnect()
        guard let url = URL(string: "ws://\(ip):\(port)/") else { return }
        print("Connecting to \(url)")
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        // Send Subscribe Request
        let subscribeMsg = "{\"request\": \"Subscribe\", \"events\": { \"TikTok\": [\"Gift\"] }, \"id\": \"123\"}"
        let message = URLSessionWebSocketTask.Message.string(subscribeMsg)
        webSocket?.send(message) { error in
            if let error = error { print("WebSocket Send Error: \(error)") }
        }
        
        DispatchQueue.main.async { self.isConnected = true }
        receiveMessage()
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        DispatchQueue.main.async { self.isConnected = false }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error receiving: \(error)")
                DispatchQueue.main.async { self?.isConnected = false }
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleJSON(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleJSON(text)
                    }
                @unknown default: break
                }
                self?.receiveMessage() // Keep listening
            }
        }
    }
    
    private func handleJSON(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {
            if event.event.source == "TikTok" && event.event.type == "Gift" {
                DispatchQueue.main.async { self.lastEvent = event }
            }
        }
    }
}

// Helper for SINGLE Alert Logic
struct GameAlert: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

// --- 3. MAIN VIEW ---
struct ContentView: View {
    // STATE
    @State private var players: [Player] = []
    @State private var bonuses: [BonusItem] = [] 
    @State private var newPlayerName: String = ""
    @StateObject private var botClient = StreamerBotClient()
    
    // SETTINGS - RENAMED DEFAULT TITLE
    @AppStorage("boardTitle") private var boardTitle = "Live\nGame Board"
    @AppStorage("boardSubtitle") private var boardSubtitle = "🎁 1k Gift = 1 Move Forward"
    @AppStorage("isHoliday") private var isHolidayTheme = true
    @AppStorage("pcIP") private var pcIP = "192.168.1.5"
    @AppStorage("wsPort") private var wsPort = "8080"
    
    // TOGGLES
    @AppStorage("enTrap") private var enableTrap = true
    @AppStorage("enSpin") private var enableSpin = true
    @AppStorage("enShirt") private var enableShirt = true
    @AppStorage("enGold") private var enableGold = true
    @AppStorage("enPoints") private var enablePoints = true
    
    // CUSTOM TILE
    @AppStorage("enCustom") private var enableCustom = false
    @AppStorage("custIndex") private var customIndex = 14
    @AppStorage("custTitle") private var customTitle = "MYSTERY BOX!"
    @AppStorage("custMsg") private var customMsg = "You found the secret stash!"
    
    // GAME LOGIC
    @State private var winnerCount: Int = 0
    @State private var showingSettings = false
    let costPerMove = 1000
    
    // SINGLE ALERT SYSTEM
    @State private var activeAlert: GameAlert?
    
    let totalTiles = 30
    let columns = [GridItem(.adaptive(minimum: 80))]
    let pawnColors: [Color] = [.red, .blue, .orange, .purple, .pink, .cyan, .green, .yellow]

    var body: some View {
        HStack(spacing: 0) {
            
            // --- LEFT SIDE: BOARD ---
            ZStack {
                // Background
                if isHolidayTheme {
                    LinearGradient(gradient: Gradient(colors: [Color(red: 0, green: 0.2, blue: 0.1), Color(red: 0, green: 0.1, blue: 0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                    VStack {
                        HStack { Image(systemName: "snowflake").font(.system(size: 40)).opacity(0.1); Spacer() }
                        Spacer()
                        HStack { Spacer(); Image(systemName: "snowflake").font(.system(size: 50)).opacity(0.1) }
                    }.padding().foregroundColor(.white)
                } else {
                    Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea()
                }
                
                // Grid & Leaderboard
                VStack {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(0..<totalTiles, id: \.self) { index in
                                let b = bonuses.first(where: { $0.tileIndex == index })
                                let effectiveBonus = isBonusEnabled(b) ? b : nil
                                TileView(index: index, players: players, colors: pawnColors, bonus: effectiveBonus, isHoliday: isHolidayTheme)
                            }
                        }
                        .padding()
                    }
                    
                    // Live Leaderboard
                    if !players.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Text("🏆 LIVE STANDINGS").font(.headline).fontWeight(.black).foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            ScrollView {
                                VStack(spacing: 4) {
                                    ForEach(sortedPlayers) { p in
                                        HStack {
                                            Text(p.finishRank != nil ? "🏁" : "Active").font(.caption2).foregroundColor(.gray).frame(width: 30)
                                            Circle().fill(pawnColors[p.colorIndex]).frame(width: 10, height: 10)
                                            Text(p.name).fontWeight(.bold).foregroundColor(p.finishRank != nil ? .yellow : .white)
                                            Text("(\(p.lifetimeCoins))").font(.caption).foregroundColor(.gray)
                                            Spacer()
                                            Text(p.finishRank != nil ? "FINISHED" : "Tile \(p.tileIndex + 1)").font(.caption).foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(8)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                                .padding()
                            }
                            .frame(height: 150)
                        }
                        .background(Color.black.opacity(0.6))
                    }
                }
            }
            
            // --- RIGHT SIDE: CONTROLS ---
            VStack(alignment: .center, spacing: 15) {
                
                // Header
                Text(boardTitle)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(isHolidayTheme ? Color.green : Color.blue)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                Text(boardSubtitle).font(.caption).bold().foregroundColor(.gray)
                
                // Connection Status
                HStack {
                    Circle().fill(botClient.isConnected ? Color.green : Color.red).frame(width: 8, height: 8)
                    Text(botClient.isConnected ? "Connected to PC" : "Disconnected")
                        .font(.caption).foregroundColor(botClient.isConnected ? .green : .red)
                }
                
                Button(action: { showingSettings = true }) {
                    Label("Settings & Connect", systemImage: "gearshape.fill").font(.caption)
                }
                
                Divider()
                
                // Manual Add
                HStack {
                    TextField("Name", text: $newPlayerName).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: addPlayer) { Image(systemName: "plus.circle.fill").font(.title2) }
                }.padding(.horizontal)
                
                // Player List
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(players) { player in
                            HStack {
                                Button(action: { delete(player: player) }) {
                                    Image(systemName: "trash").foregroundColor(.red.opacity(0.6))
                                }
                                Circle().fill(pawnColors[player.colorIndex]).frame(width: 12, height: 12)
                                
                                // FORCE BLACK TEXT for visibility
                                Text(player.name)
                                    .bold()
                                    .font(.caption)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                if player.finishRank == nil {
                                    Button(action: { move(player: player, step: -1) }) { Image(systemName: "arrow.left") }
                                    
                                    // FORCE BLACK TEXT for tile number
                                    Text("\(player.tileIndex + 1)")
                                        .font(.caption)
                                        .frame(width: 20)
                                        .foregroundColor(.black)
                                    
                                    Button(action: { move(player: player, step: 1) }) { Image(systemName: "arrow.right.circle.fill").foregroundColor(.green) }
                                } else {
                                    Image(systemName: "flag.checkered").foregroundColor(.green)
                                }
                            }
                            .padding(8).background(Color.white).cornerRadius(8)
                        }
                    }.padding(.horizontal)
                }
                
                Button("Reset Board") { resetBoard() }.foregroundColor(.red).padding(.bottom)
            }
            .frame(width: 300)
            .background(Color(white: 0.95))
        }
        .onAppear { loadData(); setupDefaultBonuses() }
        .onChange(of: botClient.lastEvent?.data.user.name) { oldValue, newValue in
            if let event = botClient.lastEvent { processGift(event) }
        }
        
        // --- SETTINGS SHEET ---
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                Form {
                    Section(header: Text("Streamer.bot Connection")) {
                        TextField("PC IP Address (e.g. 192.168.1.5)", text: $pcIP)
                        TextField("Port (e.g. 8080)", text: $wsPort)
                        Button("Connect Now") {
                            botClient.connect(ip: pcIP, port: wsPort)
                        }
                    }
                    
                    Section(header: Text("Visuals")) {
                        Toggle("Holiday Theme", isOn: $isHolidayTheme)
                        TextField("Title", text: $boardTitle)
                        TextField("Subtitle", text: $boardSubtitle)
                    }
                    
                    Section(header: Text("Power Ups")) {
                        Toggle("Trap", isOn: $enableTrap)
                        Toggle("Spin", isOn: $enableSpin)
                        Toggle("Shirt", isOn: $enableShirt)
                        Toggle("Gold", isOn: $enableGold)
                        Toggle("Points", isOn: $enablePoints)
                    }
                    
                    Section(header: Text("Custom Tile")) {
                        Toggle("Enable Custom", isOn: $enableCustom)
                        if enableCustom {
                            Stepper("Tile: \(customIndex + 1)", value: $customIndex, in: 0...29)
                            TextField("Title", text: $customTitle)
                            TextField("Message", text: $customMsg)
                        }
                    }
                    
                    Section {
                        Button("🧪 Simulate 1000 Coin Gift") { simulateGift() }
                        Button("🔀 Randomize Board") { randomizeBoard() }
                        Button("Save & Close") {
                            updateCustomBonus()
                            saveData()
                            showingSettings = false
                        }
                    }
                }.navigationTitle("Settings")
            }
        }
        // SINGLE ALERT HANDLER
        .alert(item: $activeAlert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("Awesome!")))
        }
    }
    
    // --- SORTING ---
    var sortedPlayers: [Player] {
        players.sorted {
            // 1. Finished players always top (lower rank is better)
            if let r1 = $0.finishRank, let r2 = $1.finishRank { return r1 < r2 }
            if $0.finishRank != nil { return true }
            if $1.finishRank != nil { return false }
            
            // 2. Sort by TILE INDEX (Further is better)
            if $0.tileIndex != $1.tileIndex {
                return $0.tileIndex > $1.tileIndex
            }
            
            // 3. Tie-breaker: Lifetime Coins
            return $0.lifetimeCoins > $1.lifetimeCoins
        }
    }
    
    // --- LOGIC ---
    
    func processGift(_ event: StreamerBotClient.StreamEvent) {
        let username = event.data.user.name
        let cleanName = String(username.prefix(4)).uppercased()
        let coins = (event.data.gift.coins ?? 1) * event.data.gift.count
        
        // 1. Find or Create
        var pIndex = players.firstIndex(where: { $0.name == cleanName })
        
        if pIndex == nil {
            let newPlayer = Player(name: cleanName, tileIndex: 0, colorIndex: Int.random(in: 0..<7), finishRank: nil, lifetimeCoins: 0, spendableCoins: 0)
            players.append(newPlayer)
            pIndex = players.count - 1
        }
        
        guard let idx = pIndex else { return }
        
        // 2. Add Coins
        players[idx].lifetimeCoins += coins
        players[idx].spendableCoins += coins
        
        // 3. Calc Moves
        if players[idx].spendableCoins >= costPerMove {
            let moves = players[idx].spendableCoins / costPerMove
            players[idx].spendableCoins %= costPerMove // Keep remainder
            
            move(player: players[idx], step: moves)
        }
        saveData()
    }
    
    func move(player: Player, step: Int) {
        guard let index = players.firstIndex(where: { $0.id == player.id }), players[index].finishRank == nil else { return }
        
        let newIndex = players[index].tileIndex + step
        if newIndex >= 0 && newIndex < totalTiles {
            players[index].tileIndex = newIndex
            if step > 0 { checkForBonus(index: index, tileIndex: newIndex) }
            if newIndex == totalTiles - 1 { handleWinner(index: index) }
            saveData()
        }
    }
    
    func checkForBonus(index: Int, tileIndex: Int) {
        guard let bIndex = bonuses.firstIndex(where: { $0.tileIndex == tileIndex && !$0.isClaimed }) else { return }
        let bonus = bonuses[bIndex]
        
        if !isBonusEnabled(bonus) { return }
        
        var alertTitle = ""; var alertMsg = ""; var shouldTeleport = false
        
        switch bonus.type {
        case "TRAP":
            alertTitle = "⛔️ OOPS!"; alertMsg = "\(players[index].name) fell back 1 space!";
            players[index].tileIndex = max(0, tileIndex - 1); shouldTeleport = true
        case "POINTS":
            alertTitle = "💎 LIVE POINTS!"; alertMsg = "Found the stash!"; shouldTeleport = true
        case "SPIN":
            alertTitle = "🎰 SPIN!"; alertMsg = "Spin the wheel!"; bonuses[bIndex].isClaimed = true
        case "SHIRT":
            alertTitle = "👕 SHIRT!"; alertMsg = "Name on Shirt!"; bonuses[bIndex].isClaimed = true
        case "GOLD":
            alertTitle = "👑 GOLD!"; alertMsg = "Golden Status!"; players[index].colorIndex = 7; bonuses[bIndex].isClaimed = true
        case "CUSTOM":
            alertTitle = "✨ \(bonus.customTitle ?? "Mystery")"; alertMsg = bonus.customMsg ?? "Prize!"; bonuses[bIndex].isClaimed = true
        default: break
        }
        
        activeAlert = GameAlert(title: alertTitle, message: alertMsg)
        
        if shouldTeleport {
            var newSpot = 0
            repeat { newSpot = Int.random(in: 1..<totalTiles-1) } while bonuses.contains(where: { $0.tileIndex == newSpot && !$0.isClaimed })
            bonuses[bIndex].tileIndex = newSpot
        }
        saveData()
    }
    
    func handleWinner(index: Int) {
        winnerCount += 1
        players[index].finishRank = winnerCount
        
        var title = ""
        var msg = ""
        
        if winnerCount == 1 {
            title = "🏆 GRAND PRIZE WINNER!"
            msg = "\(players[index].name) has won the Grand Prize!"
        } else if winnerCount == 2 {
            title = "🥈 2ND PLACE WINNER!"
            msg = "\(players[index].name) has won the 2nd Place Prize!"
        } else if winnerCount == 3 {
            title = "🥉 3RD PLACE WINNER!"
            msg = "\(players[index].name) has won the 3rd Place Prize!"
        } else {
            title = "🎉 FINISHER!"
            msg = "\(players[index].name) finished #\(winnerCount)!"
        }
        
        activeAlert = GameAlert(title: title, message: msg)
    }
    
    // --- HELPERS ---
    func addPlayer() {
        let name = String(newPlayerName.prefix(4)).uppercased()
        if name.isEmpty { return }
        players.append(Player(name: name, tileIndex: 0, colorIndex: Int.random(in: 0..<7), finishRank: nil, lifetimeCoins: 0, spendableCoins: 0))
        newPlayerName = ""
        saveData()
    }
    func delete(player: Player) { players.removeAll(where: { $0.id == player.id }); saveData() }
    
    func resetBoard() {
        players.removeAll()
        winnerCount = 0
        bonuses.removeAll() // Clear old ones
        setupDefaultBonuses() // Add defaults
        updateCustomBonus() // Add custom if enabled
        
        // FORCE RESET TITLE
        boardTitle = "Live\nGame Board"
        
        saveData()
    }
    
    func isBonusEnabled(_ b: BonusItem?) -> Bool {
        guard let b = b else { return false }
        switch b.type {
        case "TRAP": return enableTrap; case "SPIN": return enableSpin; case "SHIRT": return enableShirt
        case "GOLD": return enableGold; case "POINTS": return enablePoints; case "CUSTOM": return enableCustom
        default: return true
        }
    }
    func simulateGift() {
        let fakeEvent = StreamerBotClient.StreamEvent(
            event: .init(source: "TikTok", type: "Gift"),
            data: .init(user: .init(name: "TEST_\(Int.random(in: 1...99))"), gift: .init(name: "Galaxy", count: 1, coins: 1000))
        )
        processGift(fakeEvent)
    }
    func randomizeBoard() {
        for i in 0..<bonuses.count {
            var newSpot = 0
            repeat { newSpot = Int.random(in: 1..<totalTiles-1) } while bonuses.contains(where: { $0.tileIndex == newSpot && $0.id != bonuses[i].id })
            bonuses[i].tileIndex = newSpot
        }
        saveData()
    }
    func updateCustomBonus() {
        bonuses.removeAll { $0.type == "CUSTOM" }
        if enableCustom {
            bonuses.append(BonusItem(tileIndex: customIndex, type: "CUSTOM", isClaimed: false, customTitle: customTitle, customMsg: customMsg))
        }
    }
    
    // --- PERSISTENCE ---
    func saveData() {
        if let encoded = try? JSONEncoder().encode(players) { UserDefaults.standard.set(encoded, forKey: "savedPlayers") }
        if let encodedB = try? JSONEncoder().encode(bonuses) { UserDefaults.standard.set(encodedB, forKey: "savedBonuses") }
        UserDefaults.standard.set(winnerCount, forKey: "winnerCount")
    }
    func loadData() {
        if let data = UserDefaults.standard.data(forKey: "savedPlayers"), let decoded = try? JSONDecoder().decode([Player].self, from: data) { players = decoded }
        if let data = UserDefaults.standard.data(forKey: "savedBonuses"), let decoded = try? JSONDecoder().decode([BonusItem].self, from: data) { bonuses = decoded }
        winnerCount = UserDefaults.standard.integer(forKey: "winnerCount")
    }
    func setupDefaultBonuses() {
        if bonuses.isEmpty {
            bonuses = [
                BonusItem(tileIndex: 6, type: "TRAP", isClaimed: false),
                BonusItem(tileIndex: 11, type: "SPIN", isClaimed: false),
                BonusItem(tileIndex: 17, type: "SHIRT", isClaimed: false),
                BonusItem(tileIndex: 19, type: "GOLD", isClaimed: false),
                BonusItem(tileIndex: 24, type: "POINTS", isClaimed: false),
                BonusItem(tileIndex: 8, type: "POINTS", isClaimed: false)
            ]
        }
    }
}

struct AlertItem: Identifiable { var id = UUID(); var title: String; var message: String }

// --- 4. TILE & PAWN ---
struct TileView: View {
    let index: Int; let players: [Player]; let colors: [Color]; let bonus: BonusItem?; let isHoliday: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(tileColor)
                .frame(height: 80)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: isSpecial ? 3 : 1))
                .shadow(color: isHoliday ? .white.opacity(0.05) : .black.opacity(0.5), radius: 5)
            
            Text("\(index + 1)").font(.caption).bold().foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(6)
            
            if isSpecial { Image(systemName: iconName).font(.largeTitle).foregroundColor(.white.opacity(0.8)) }
            
            // Pawns
            let here = players.filter { $0.tileIndex == index }
            if let first = here.first {
                PawnView(name: first.name, color: colors[first.colorIndex])
                if here.count > 1 {
                    ZStack { Circle().fill(.white).frame(width: 20); Text("+\(here.count-1)").font(.caption2).foregroundColor(.red) }
                        .offset(x: 20, y: -20)
                }
            }
        }
    }
    
    var isSpecial: Bool { index == 29 || (bonus != nil && !bonus!.isClaimed) }
    var tileColor: Color {
        guard let b = bonus, !b.isClaimed, b.type != "TRAP" else { return isHoliday ? Color.white.opacity(0.15) : Color.white.opacity(0.05) }
        switch b.type {
        case "SHIRT": return .orange.opacity(0.3); case "SPIN": return .green.opacity(0.3); case "GOLD": return .yellow.opacity(0.3)
        case "POINTS": return .purple.opacity(0.3); case "CUSTOM": return .pink.opacity(0.3); default: return .gray.opacity(0.3)
        }
    }
    var borderColor: Color {
        if index == 29 { return .yellow }
        guard let b = bonus, !b.isClaimed, b.type != "TRAP" else { return .white.opacity(0.3) }
        switch b.type {
        case "SHIRT": return .orange; case "SPIN": return .green; case "GOLD": return .yellow; case "POINTS": return .purple; case "CUSTOM": return .pink; default: return .white
        }
    }
    var iconName: String {
        if index == 29 { return "star.fill" }
        guard let b = bonus, !b.isClaimed, b.type != "TRAP" else { return "" }
        switch b.type {
        case "SHIRT": return "tshirt.fill"; case "SPIN": return "circle.dashed.inset.filled"; case "GOLD": return "crown.fill"
        case "POINTS": return "suit.diamond.fill"; case "CUSTOM": return "gift.fill"; default: return "circle.fill"
        }
    }
}

struct PawnView: View {
    let name: String; let color: Color
    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 45, height: 45).shadow(radius: 2)
            Circle().stroke(.white, lineWidth: 2).frame(width: 45, height: 45)
            Text(name).font(.system(size: 11, weight: .heavy)).foregroundColor(.white).shadow(radius: 1)
        }
    }
}

#Preview {
    ContentView()
}
