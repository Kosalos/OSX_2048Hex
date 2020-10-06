import Cocoa

class ViewController: NSViewController {
    
    @IBAction func buttonA(_ sender: NSButton) { game.keyDown("A") }
    @IBAction func buttonS(_ sender: NSButton) { game.keyDown("S") }
    @IBAction func buttonQ(_ sender: NSButton) { game.keyDown("Q") }
    @IBAction func buttonW(_ sender: NSButton) { game.keyDown("W") }
    @IBAction func buttonZ(_ sender: NSButton) { game.keyDown("Z") }
    @IBAction func buttonX(_ sender: NSButton) { game.keyDown("X") }
    @IBAction func buttonUndo(_ sender: NSButton) { game.undo() }
    @IBAction func buttonNewGame(_ sender: NSButton) { game.keyDown(" ")  }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        game.newGame()
        Timer.scheduledTimer(withTimeInterval:0.05, repeats:true) { timer in self.timerHandler() }
    }
    
    @objc func timerHandler() {
        game.timerHandler()
    }
}

