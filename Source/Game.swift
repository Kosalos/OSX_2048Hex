import Cocoa
import AppKit

let XMAX = 6
let YMAX = 6
let SCREEN_XS:CGFloat = 500 // logical screen size
let SCREEN_YS:CGFloat = 512
let EMPTY = 0

struct Board {
    var cell = Array(repeating: Array(repeating:Int(), count:YMAX), count:XMAX)
    
    func number(_ x:Int, _ y:Int) -> String {
        return cell[x][y] == EMPTY ? " " : cell[x][y].description
    }
    
    func isIsland(_ x:Int, _ y:Int) -> Bool {
        return true
    }
    
    mutating func copy(_ src:Board) {
        for x in 0 ..< XMAX {
            for y in 0 ..< YMAX {
                cell[x][y] = src.cell[x][y]
            }
        }
    }
}

var game = Game()
var board = Board()
var undoBoard = Board()
var temp = Board()

//MARK: -

var animate:[Animate] = []
var animateCurrentIndex = Int()

struct Animate {
    var sx = 0              // starting cell index
    var sy = 0
    var ex = 0              // ending cell index
    var ey = 0
    var travelingValue = 0  // value to display while animation is in progress
    var finalValue = 0      // value to save to board cell after animation completes
    var p1 = CGPoint()      // screen coordinate of starting cell position
    var p2 = CGPoint()      // screen coordinate of ending cell position
    
    init(_ x:Int, _ y:Int) {
        sx = x; ex = x
        sy = y; ey = y
        travelingValue = board.cell[x][y]
        finalValue = travelingValue
        
        animateCurrentIndex = animate.count
        p1 = game.cellPosition(sx,sy)
    }
    
    mutating func updateAnimationEnding(_ x:Int, _ y:Int, _ v:Int) {
        ex = x
        ey = y
        finalValue = v
        p2 = game.cellPosition(ex,ey)
    }
}

//MARK: -

let backgroundColor = NSColor.init(red:0.2, green:0.4, blue:0.1, alpha:1)

let c0 = CGFloat(0.0)
let c1 = CGFloat(0.3)
let c2 = CGFloat(0.5)
let c3 = CGFloat(0.7)

let cellColors:[NSColor] = [
    NSColor.init(red:c0, green:c1, blue:c0, alpha:1),    // 2
    NSColor.init(red:c3, green:c2, blue:c0, alpha:1),    // 4
    NSColor.init(red:c0, green:c3, blue:c0, alpha:1),    // 8
    NSColor.init(red:c0, green:c1, blue:c1, alpha:1),    // 16
    NSColor.init(red:c0, green:c1, blue:c2, alpha:1),    // 32
    NSColor.init(red:c0, green:c1, blue:c3, alpha:1),    // 64
    NSColor.init(red:c1, green:c1, blue:c1, alpha:1),    // 128
    NSColor.init(red:c1, green:c1, blue:c2, alpha:1),    // 256
    NSColor.init(red:c2, green:c1, blue:c3, alpha:1),    // 512
    NSColor.init(red:c2, green:c1, blue:c3, alpha:1),    // 1024
    NSColor.init(red:c3, green:c1, blue:c3, alpha:1),    // 2048
]

func cellColor(_ value:Int) -> CGColor {
    if value == EMPTY { return NSColor.gray.cgColor }
    
    var index = 0
    var v = value
    while v > 2 { v /= 2;  index += 1 }
    return cellColors[index].cgColor
}

//MARK: -

class Game {
    var score = Int()
    var animationRatio = CGFloat()
    var animationSpeed = CGFloat() // ease in / ease out control
    
    func isOdd(_ value:Int) -> Bool { return value & 1 != 0 }
    
    func isLegalCellIndex(_ x:Int, _ y:Int) -> Bool {
        if x == XMAX-1 && isOdd(y) { return false }
        return x >= 0 && x < XMAX && y >= 0 && y < YMAX
    }
    
    let offsetO:[(x:Int, y:Int)] = [ ( 0,-1), (1,-1), (-1,0), (1,0), ( 0,1), (1,1)]  // offsets of neighboring cells
    let offsetE:[(x:Int, y:Int)] = [ (-1,-1), (0,-1), (-1,0), (1,0), (-1,1), (0,1)]
    
    //MARK: -
    
    func newGame() {
        score = 0
        animate.removeAll()
        
        for x in 0 ..< XMAX {
            for y in 0 ..< YMAX {
                board.cell[x][y] = EMPTY
            }
        }

        addRandomCell()
        addRandomCell()
        
        undoBoard.copy(board)
        
        quartzView.refresh()
    }

    //MARK: -

    func addRandomCell() {
        for _ in 0 ..< 1000 {
            let x = Int.random(in: 0 ... XMAX-1)
            let y = Int.random(in: 0 ... YMAX-1)
            if isLegalCellIndex(x,y) && board.cell[x][y] == EMPTY {
                board.cell[x][y] = Int.random(in: 0 ... 4) < 1 ? 4 : 2
                return
            }
        }
        
        // all cells filled:  game over
    }
    
    //MARK: -
    
    var mergeAlreadyPerformed = Bool()
    
    func slideCell(_ x:Int, _ y:Int, _ dx:Int, _ dy:Int) {
        if !isLegalCellIndex(x,y)  { return }
        
        var nx = x + dx
        let ny = y + dy
        
        if dy != 0 {
            if dx < 0 && !isOdd(ny) { nx += 1 }
            if dx > 0 &&  isOdd(ny) { nx -= 1 }
        }
        
        if !isLegalCellIndex(nx,ny)  { return }
        
        // merge into cell we bumped into ----------------
        if !mergeAlreadyPerformed && temp.cell[nx][ny] == temp.cell[x][y]  {
            mergeAlreadyPerformed = true
            temp.cell[x][y] = EMPTY
            temp.cell[nx][ny] *= 2
            animate[animateCurrentIndex].updateAnimationEnding(nx,ny,temp.cell[nx][ny])
            
            score += temp.cell[nx][ny]
        }
        
        // move into neighboring empty cell -------------
        if temp.cell[nx][ny] == EMPTY  {
            temp.cell[nx][ny] = temp.cell[x][y]
            temp.cell[x][y] = EMPTY
            
            animate[animateCurrentIndex].updateAnimationEnding(nx,ny,temp.cell[nx][ny])
            
            slideCell(nx,ny,dx,dy) // continue sliding
        }
    }
    
    func slideAllCellsInThisDirection(_ dx:Int, _ dy:Int) {
        if animate.count > 0 { return }  // still completing previous move
        temp.copy(board)
        undoBoard.copy(board)
        
        let sx = dx > 0 ? XMAX-1 : 0 // visit cells that will be slid into first
        let sy = dy > 0 ? YMAX-1 : 0
        
        var x = sx
        var y = sy
        
        animate.removeAll()
        animationRatio = 0
        animationSpeed = 0.08
        
        mergeAlreadyPerformed = false

        while true {
            // board position holds a value. attempt to slide and/or merge
            if temp.cell[x][y] != EMPTY  {
                animate.append(Animate(x,y))    // assume it will slide
                slideCell(x,y,dx,dy)
            }
            
            // if cell did not move then remove its entry from animation storage
            if let an = animate.last {
                if an.sx == an.ex && an.sy == an.ey {
                    animate.removeLast()
                }
            }
            
            x -= dx
            if x < 0 || x >= XMAX {
                x = sx
                y -= dy
                if dy == 0 { y += 1 }   // horizontal movement. ensure we visit all rows of board
                if y < 0 || y >= YMAX { break }

                mergeAlreadyPerformed = false
            }
        }
        
        // prepare for animate session. clear cells that begin animations
        for i in 0 ..< animate.count {
            let an = animate[i]
            board.cell[an.sx][an.sy] = EMPTY
        }
    }
    
    //MARK: -
    
    func timerHandler() {
        func isAnimationInProgress() -> Bool { return animate.count > 0 && animationRatio < 1 }
        
        if isAnimationInProgress() {
            if animationRatio <= 0.5 { animationSpeed *= 1.1 } else { animationSpeed *= 0.9 }
            animationRatio += min(animationSpeed, 0.1)
            
            if !isAnimationInProgress() { // animation has completed
                
                for an in animate { // update cell values (may have affected by a merge)
                    board.cell[an.ex][an.ey] = an.finalValue
                }
                
                animate.removeAll()
                
                addRandomCell()
            }
            
            quartzView.refresh()
        }
    }
    
    //MARK: - draw
    
    let ULcornerX:CGFloat = 100
    let ULcornerY:CGFloat = 50
    
    let CellSize:CGFloat = 40
    let CellRadiusY:CGFloat = 20
    let CellRadiusX:CGFloat = 20 * CGFloat(sqrtf(3))
    let CellHopX:CGFloat = 0.05 + 22.0/12
    let CellHopY:CGFloat = 0.05 + 13.0/8
    
    func startShadow() {
        context!.saveGState()
        context?.setShadow(offset: CGSize(width:3, height:-3), blur:3, color: NSColor.black.cgColor)
    }
    
    func endShadow() {
        context!.restoreGState()
    }

    func drawCellAtPosition(_ cp:CGPoint, _ value:Int) {
        NSColor.black.setStroke()
        context?.setFillColor(cellColor(value))
        context?.setLineWidth(2)
        
        context?.move(   to: CGPoint(x:cp.x,             y:cp.y-CellSize))
        context?.addLine(to: CGPoint(x:cp.x+CellRadiusX, y:cp.y-CellRadiusY))
        context?.addLine(to: CGPoint(x:cp.x+CellRadiusX, y:cp.y+CellRadiusY))
        context?.addLine(to: CGPoint(x:cp.x,             y:cp.y+CellSize))
        context?.addLine(to: CGPoint(x:cp.x-CellRadiusX, y:cp.y+CellRadiusY))
        context?.addLine(to: CGPoint(x:cp.x-CellRadiusX, y:cp.y-CellRadiusY))
        context?.addLine(to: CGPoint(x:cp.x,             y:cp.y-CellSize))
        
        context?.drawPath(using: .fillStroke)
        
        if value != EMPTY {  // display cell value
            let yOffset:CGFloat = value >= 1000 ? -16 : -22
            let fontSize:Int = value >= 1000 ? 24 : 32
            
            startShadow()
            drawText(cp.x, cp.y + yOffset, value.description, fontSize, .white, 1)
            endShadow()
        }
    }
    
    func drawCell(_ x:Int, _ y:Int) {
        if x == XMAX-1 && isOdd(y) { return }
        drawCellAtPosition(cellPosition(x,y),board.cell[x][y])
    }
    
    func draw() {
        backgroundColor.set()
        drawFilledRectangle(0,0,5000,5000)
        drawInstructions()
        drawScore()
        
        for x in 0 ..< XMAX {
            for y in 0 ..< YMAX {
                drawCell(x,y)
            }
        }
        
        if animationRatio < 1 {
            for an in animate {
                var pos = an.p1
                pos.x += (an.p2.x - an.p1.x) * animationRatio
                pos.y += (an.p2.y - an.p1.y) * animationRatio
                drawCellAtPosition(pos,an.travelingValue)
            }
        }
    }
    
    //MARK: -

    func undo() {
        board.copy(undoBoard)
        quartzView.refresh()
    }
    
    //MARK: -

    let instructions:[String] = [
        "Slide cells in specified direction.",
    ]

    func drawInstructions() {
        startShadow()

        let x:CGFloat = 20
        var y:CGFloat = 640
        drawText(x,y,"2048 Hex",24,.white,0)
        y += 32
        for s in instructions {
            drawText(x,y,s,18,.white,0)
            y += 20
        }

        endShadow()
    }
    
    func drawScore() {
        startShadow()

        let str = String(format: "Score: %d",score)
        drawText(20,590,str,36,.yellow,0)

        endShadow()
    }

    //MARK: -
    
    func keyDown(_ key:String) {
        switch key {
        case "Q" : slideAllCellsInThisDirection(-1,0)
        case "W" : slideAllCellsInThisDirection(+1,0)
        case "A" : slideAllCellsInThisDirection(-1,-1)
        case "S" : slideAllCellsInThisDirection(+1,+1)
        case "Z" : slideAllCellsInThisDirection(-1,+1)
        case "X" : slideAllCellsInThisDirection(+1,-1)
        case " " : newGame()
        default : break
        }
    }
    
    func cellPosition(_ x:Int, _ y:Int) -> CGPoint {
        var pt = CGPoint()
        pt.x = ULcornerX + CGFloat(x) * CellSize * CellHopX
        pt.y = ULcornerY + CGFloat(y) * CellSize * CellHopY
        if !isOdd(y) { pt.x -= CellSize * 23/24 }

        return pt
    }
}

