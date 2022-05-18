 
import SpriteKit
import GameplayKit

/**
 * Game scene class that controls the app logic.
 *
 * New and improved: instead of altering the Sprite/PhysicsBody that is a child
 * of the player, we're going to alter the textures attached to the player
 * himself.
 *
 * Jack Lais and co., 05/12/22
 */
class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // Nodes, which contain player object and related
    var gameNode: SKNode!
    var groundNode: SKNode!
    var backgroundNode: SKNode!
    var barrelNode: SKNode!
    var sahilNode: SKNode!
    var jumpNode: SKNode!
    
    
    // Score-related variables
    var scoreNode: SKLabelNode!
    var resetInstructions: SKLabelNode!
    var score = 0 as Int
    
    // Status variables that keep track of where Sahil is
    var groundCheck: Bool = true
    var gameOverCheck: Bool = false
    
    // Sound effects
    let jumpSound = SKAction.playSoundFileNamed("sahil.assets/sounds/jumpSFX", waitForCompletion: false)
    let dieSound = SKAction.playSoundFileNamed("sahil.assets/sounds/die", waitForCompletion: false)

    // Textures
    var deadTexture: SKTexture!
    
    // Sprites that manage textures and associated physics
    var activeSprite: SKSpriteNode!
    var defaultSprite: SKSpriteNode!
    var jumpingSprite: SKSpriteNode!

    
    // Spawning vars for barrels
    var spawnRate = 1.5 as Double
    var timeSinceLastSpawn = 0.0 as Double
    
    // Generic vars that declare game positions
    var groundHeight: CGFloat?
    var sahilYPosition: CGFloat?
    var jumpYPosition: CGFloat?
    var groundSpeed = 1000 as CGFloat
    
    // Consts controlling game movement
    let sahilHopForce = 750 as Int
    let cloudSpeed = 50 as CGFloat
    let sunSpeed = 10 as CGFloat
    
    let background = 0 as CGFloat
    let foreground = 1 as CGFloat
    
    // Masks for collision categories
    let groundCategory = 1 << 0 as UInt32
    let sahilCategory = 1 << 1 as UInt32
    let barrelCategory = 1 << 2 as UInt32
    

    // Scales
    var deadScale: CGFloat = 0.3
    var sahilScale: CGFloat = 0.6
    var jumpScale: CGFloat = 0.6
    var jumpHitScale: CGFloat = 0.7
    
    //important variables
    var physicsBox: CGSize!
    var runningAnimation: SKAction!
    var jumpAnimation: SKAction!
    
    // Entry point for the application.
    // Performes first-time initialization and then resets (starts) the game.
    override func didMove(to view: SKView) {
        
        // Add the background to the GameScene
        let bGround = SKSpriteNode(imageNamed: "sahil.assets/landscape/skyGround.png")
        bGround.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(bGround)
        
        // Establish gravity and physics
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = CGVector(dx: 0.0, dy: -9.8)
        
        //ground
        groundNode = SKNode()
        groundNode.zPosition = background
        createAndMoveGround()
        addCollisionToGround()
        
        //background elements
        backgroundNode = SKNode()
        backgroundNode.zPosition = background
         createSun()
        createClouds()
        
        //sahil
        sahilNode = SKNode()
        sahilNode.zPosition = foreground
        //createSahil() not needed, handled by resetGame
        
        //barrels
        barrelNode = SKNode()
        barrelNode.zPosition = foreground
        
       
        
        //score
        let scoreHeight = self.frame.size.height
        score = 0
        scoreNode = SKLabelNode(fontNamed: "Arial")
        scoreNode.fontSize = 30
        scoreNode.zPosition = foreground
        scoreNode.text = "Score: 0"
        scoreNode.fontColor = SKColor.gray
        scoreNode.position = CGPoint(x: 200, y: scoreHeight - 50)
        
        //reset instructions
        resetInstructions = SKLabelNode(fontNamed: "Arial")
        resetInstructions.fontSize = 50
        resetInstructions.text = "Tap to Restart"
            
        //resetInstructions.text.opacity(0)
        resetInstructions.position = CGPoint(x: 1000, y: 10000)
        
        //parent game node
        gameNode = SKNode()
        gameNode.addChild(groundNode)
        gameNode.addChild(backgroundNode)
        gameNode.addChild(sahilNode)
        gameNode.addChild(barrelNode)
        gameNode.addChild(scoreNode)
        gameNode.addChild(resetInstructions)
        self.addChild(gameNode)

        // Do other first-time setup.
        initTexturesAndScales()

        // Perform the per-game reset
        resetGame()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        // Debug 2
        print("Touch begin, groundCheck is \(groundCheck)")
        
        if(gameNode.speed < 1.0){
            resetGame()
            return
        }
        
        for _ in touches {
            /*make a boolean statement and calculate how long a jump is.
            Use the length of the jump and set boolean false for
            the time its in midair. Once it hits that timer, set boolean to true
            letting the sahil able to jump agian
            */
            
            if groundCheck {
                print("Handling Jump Logic")
                
                // Remove the default sprite, make the jumping animation
                //sahilSprite.removeFromParent()
                // implicitly handles ground check
                //sahilNode.removeAllChildren()
                createJump()
        
                
            }
        }
    }
    
    // Called before each frame is rendered
    override func update(_ currentTime: TimeInterval) {
        
        // Gradually speed up the game every time the update is called,
        // which leads to higher score!
        if(gameNode.speed > 0){
            groundSpeed += 0.15
            
            score += 1
            scoreNode.text = "Score: \(score/5)"
            
            if(currentTime - timeSinceLastSpawn > spawnRate){
                timeSinceLastSpawn = currentTime
                spawnRate = Double.random(in: 1.0 ..< 3.5)
                
                
                if(Int.random(in: 0...10) < 8){
                    spawnBarrel()
                }
            }
        }
        
         
         
    }
    
    // Function called at the start of any physics bodies
    func didBegin(_ contact: SKPhysicsContact) {
        print("Contact: \(contact.bodyA.node), \(contact.bodyB.node)")

        // If you hit a barrel, game over
        if (!gameOverCheck) {
            if(hitBarrel(contact)) {
                run(dieSound)
                //resetInstructions.position = CGPoint(x: 1000, y: self.frame.midY)
                gameOver()
            }
            // else if you hit the ground, then regain the ability to jump
            else if hitGround(contact) {
                endJump()
            }
        }
    }
    
    // Functions that check if you hit the ground, barrel, etc.
    func hitBarrel(_ contact: SKPhysicsContact) -> Bool {
        return contact.bodyA.categoryBitMask & barrelCategory == barrelCategory ||
            contact.bodyB.categoryBitMask & barrelCategory == barrelCategory
    }
    
    func hitGround (_ contact: SKPhysicsContact) -> Bool {
        let output = contact.bodyA.categoryBitMask & groundCategory == groundCategory ||
                contact.bodyB.categoryBitMask & groundCategory == groundCategory
        //print("Hit ground? \(output)")
        return output
    }

   

    // one-time initialization for textures and scales
    func initTexturesAndScales() {

        // Make the jumping animation textures
        var jumpTextures: [SKTexture] = []
        for i in 1..<22 {
            jumpTextures.append(SKTexture(imageNamed: "sahil.assets/jump/frame_\(String(format: "%05d", i)).png"))
            jumpTextures[i-1].filteringMode = .nearest
        }
        jumpAnimation = SKAction.animate(with: jumpTextures, timePerFrame: 0.05)
        sahilScale = 0.5

        // Make the running animation textures
        var sahilTextures: [SKTexture] = []
        for i in 1..<13 {
            sahilTextures.append(SKTexture(imageNamed: "sahil.assets/sprint/frame_\(String(format: "%05d", i)).png"))
            sahilTextures[i-1].filteringMode = .nearest
        }
        runningAnimation = SKAction.animate(with: sahilTextures, timePerFrame: 0.05)
        jumpScale = 0.5

        // Make the dead texture and scale
        deadTexture = SKTexture(imageNamed: "sahil.assets/sahilStills/dead")
        deadTexture.filteringMode = .nearest
        deadScale = 0.4

        // Make the physics box for Sahil
        physicsBox = CGSize(width: sahilTextures[0].size().width * sahilScale,
                                height: sahilTextures[0].size().height * sahilScale)
    }

    // multi-time initialization for game variables
    func initGameVariables() {

        // Set in-game parameters
        gameNode.speed = 1.0
        timeSinceLastSpawn = 0.0
        groundSpeed = 500
        score = 0

        // Set stateful variables
        groundCheck = true
        gameOverCheck = false

    }
    
    func resetGame() {

        // Reinitialize game variables.
        initGameVariables()

        // Remove the children from all nodes.
        sahilNode.removeAllChildren()
        barrelNode.removeAllChildren()

        // Reinitialize Sahil
        createSahil()
        
        // Move the reset instructions off screen
        resetInstructions.position = CGPoint(x: 1000, y: 10000)
        resetInstructions.fontColor = SKColor.cyan

        // Reset the position of the active sprite.
        activeSprite.position = CGPoint(x: self.frame.size.width * 0.2, y: sahilYPosition!)
        print(activeSprite.position)
    }

    // Set the sprite texture with a custom scaling.
    func setStaticSpriteTexture(texture: SKTexture, scale: CGFloat) {
        activeSprite.removeAllActions()
        let action = SKAction.setTexture(texture, resize: true)
        activeSprite.run(action)
        activeSprite.size = texture.size()
        activeSprite.setScale(scale)
    }

    // Set the static sprite texture with a custom scaling.
    func setAnimatedSpriteAnimation(animation: SKAction, scale: CGFloat) {
        // Prevent clutter
        activeSprite.removeAllActions()
        activeSprite.setScale(scale)
        activeSprite.run(SKAction.repeatForever(animation))
    }
    
    func gameOver() {
        gameOverCheck = true
        gameNode.speed = 0.0
        
        resetInstructions.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        resetInstructions.fontColor = SKColor.black

        // TO DO: CHANGE THE TEXTURE AND THE SCALE ON THE DEAD SPRITE.
        setStaticSpriteTexture(texture: deadTexture, scale: deadScale)
    }
    
    func createAndMoveGround() {
        let screenWidth = self.frame.size.width
        
        
        //ground texture
        let groundTexture = SKTexture(imageNamed: "sahil.assets/landscape/ground.png")
        groundTexture.filteringMode = .nearest
        
       //let homeButtonPadding = 50.0 as CGFloat
        // play around this this to get the ground to render correctly/
        // place the player at the correct height?
        groundHeight = groundTexture.size().height// * 0.5
        
        //ground actions
        
        //SKAction.moveBy(x: -groundTexture.size().width
        //duration: TimeInterval(screenWidth / groundSpeed)
        let moveGroundLeft = SKAction.moveBy(x: -groundTexture.size().width,
                                             y: 0.0, duration: TimeInterval(screenWidth / groundSpeed))
        let resetGround = SKAction.moveBy(x: groundTexture.size().width, y: 0.0, duration: 0.0)
        let groundLoop = SKAction.sequence([moveGroundLeft, resetGround])
        
        //ground nodes
        let numberOfGroundNodes = 1 + Int(ceil(screenWidth / groundTexture.size().width))
        
        for i in 0 ..< numberOfGroundNodes {
            let node = SKSpriteNode(texture: groundTexture)
            node.anchorPoint = CGPoint(x: 0.0, y: 0.5)
            node.position = CGPoint(x: CGFloat(i) * groundTexture.size().width, y: groundHeight!)
            groundNode.addChild(node)
            node.run(SKAction.repeatForever(groundLoop))
        }
    }
    
    func addCollisionToGround() {
        let groundContactNode = SKNode()
        groundContactNode.position = CGPoint(x: 0, y: groundHeight! - 30)
        
        groundContactNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.frame.size.width * 3, height: groundHeight!))
        groundContactNode.physicsBody?.friction = 0.0
        groundContactNode.physicsBody?.isDynamic = false
        groundContactNode.physicsBody?.categoryBitMask = groundCategory
        // resititution controls bounciness of the physicsbody
        groundContactNode.physicsBody?.restitution = 0.0
        
        groundNode.addChild(groundContactNode)
    }
    
    func  createSun() {
        //texture
        let sunTexture = SKTexture(imageNamed: "sahil.assets/landscape/sun")
        let sunScale = 1.0 as CGFloat
        sunTexture.filteringMode = .nearest
        
        //sun sprite
        let sunSprite = SKSpriteNode(texture: sunTexture)
        sunSprite.setScale(sunScale)
        //add to scene
        backgroundNode.addChild(sunSprite)
        
        //animate the sun
        animateSun(sprite: sunSprite, textureWidth: sunTexture.size().width * sunScale)
    }
    
    func animateSun(sprite: SKSpriteNode, textureWidth: CGFloat) {
        let screenWidth = self.frame.size.width
        let screenHeight = self.frame.size.height
        
        let distanceOffscreen = 50.0 as CGFloat // want to start the sun offscreen
        let distanceBelowTop = 150 as CGFloat
        
        //sun actions
        let moveSun = SKAction.moveBy(x: -screenWidth - textureWidth - distanceOffscreen,
                                       y: 0.0, duration: TimeInterval(screenWidth / sunSpeed))
        let resetSun = SKAction.moveBy(x: screenWidth + distanceOffscreen, y: 0.0, duration: 0)
        let sunLoop = SKAction.sequence([moveSun, resetSun])
        
        sprite.position = CGPoint(x: screenWidth + distanceOffscreen, y: screenHeight - distanceBelowTop)
        sprite.run(SKAction.repeatForever(sunLoop))
    }
    
    func createClouds() {
        
        let cloudTextures = ["cloud1", "cloud2", "cloud3", "cloud4", "cloudTennis"]
        let cloudScale = 0.5 as CGFloat
        
        
        
        //clouds
        let numClouds = 3
        for i in 0 ..< numClouds {
            //texture
            let cloudTexture = SKTexture(imageNamed: "sahil.assets/landscape/" + cloudTextures.randomElement()!)
            cloudTexture.filteringMode = .nearest
            
            //create sprite
            let cloudSprite = SKSpriteNode(texture: cloudTexture)
            cloudSprite.setScale(cloudScale)
            //add to scene
            backgroundNode.addChild(cloudSprite)
            
            //animate the cloud
            animateCloud(cloudSprite, cloudIndex: i, textureWidth: cloudTexture.size().width * cloudScale)
        }
    }
    
    func animateCloud(_ sprite: SKSpriteNode, cloudIndex i: Int, textureWidth: CGFloat) {
        let screenWidth = self.frame.size.width
        let screenHeight = self.frame.size.height
        
        let cloudOffscreenDistance = (screenWidth / 3.0) * CGFloat(i) + 100 as CGFloat
        let cloudYPadding = 50 as CGFloat
        let cloudYPosition = screenHeight - (CGFloat(i) * cloudYPadding) - 200
        
        let distanceToMove = screenWidth + cloudOffscreenDistance + textureWidth
        
        //actions
        let moveCloud = SKAction.moveBy(x: -distanceToMove, y: 0.0, duration: TimeInterval(distanceToMove / cloudSpeed))
        let resetCloud = SKAction.moveBy(x: distanceToMove, y: 0.0, duration: 0.0)
        let cloudLoop = SKAction.sequence([moveCloud, resetCloud])
        
        sprite.position = CGPoint(x: screenWidth + cloudOffscreenDistance, y: cloudYPosition)
        sprite.run(SKAction.repeatForever(cloudLoop))
    }
    
    func createSahil() {
        // Get the screen width
        // let screenWidth = self.frame.size.width

        // Remove any extra things and add a nice new body
        activeSprite = SKSpriteNode()
        
        // Reset the activeSprite's physicsBody every time it's reset.
        activeSprite.physicsBody = SKPhysicsBody(rectangleOf: physicsBox)
        activeSprite.physicsBody?.isDynamic = true
        activeSprite.physicsBody?.mass = 1.0
        activeSprite.physicsBody?.categoryBitMask = sahilCategory
        activeSprite.physicsBody?.contactTestBitMask = barrelCategory | groundCategory
        activeSprite.physicsBody?.collisionBitMask = groundCategory
        activeSprite.physicsBody?.restitution = 0.0
        
        // Needed to get the animation running for some reason
        setStaticSpriteTexture(texture: SKTexture(imageNamed: "sahil.assets/sprint/frame_00001.png"), scale: sahilScale)
        
        // Set the position off the sahilNode
        sahilYPosition = getGroundHeight() + physicsBox.height
        activeSprite.position = CGPoint(x: self.frame.size.width * 0.15, y: sahilYPosition!)
        setAnimatedSpriteAnimation(animation: runningAnimation, scale: sahilScale)
        
        // Set sahil node's child
        sahilNode.removeAllChildren()
        sahilNode.addChild(activeSprite)
    }
    
    func createJump() {
        // Set the state: we are in the jump now
        groundCheck = false
        
        // Just replace the state!
        setAnimatedSpriteAnimation(animation: jumpAnimation, scale: jumpScale)
        if activeSprite.position.y <= (sahilYPosition ?? 0) && gameNode.speed > 0 {
            print("Apply impulse")
            print(sahilHopForce)
            print(activeSprite.physicsBody?.velocity)
           
            activeSprite.physicsBody?.applyImpulse(CGVector(dx: 0, dy: sahilHopForce))
            run(jumpSound)
        }
    }
    
    func endJump() {
        // Replace textures and state.
        // This might get called multiple times if ground is bouncy
        // make sure restitution is set to 0 for both the activeSprite an
        // groundContactNode physicsBody
        setAnimatedSpriteAnimation(animation: runningAnimation, scale: sahilScale)
        groundCheck = true
    }
    
    func spawnBarrel() {
        //default was 3
        //let barrelTextures = ["barrel"] not used!
        let barrelScale = 0.3 as CGFloat
        let hitBoxScale = 0.9 as CGFloat
        //texture
        let barrelTexture = SKTexture(imageNamed: "sahil.assets/obstacles/barrel")
        barrelTexture.filteringMode = .nearest
        
        //sprite
        let barrelSprite = SKSpriteNode(texture: barrelTexture)
        barrelSprite.setScale(barrelScale)
        
        //physics
        let contactBox = CGSize(width: barrelTexture.size().width * (barrelScale * hitBoxScale),
                                height: barrelTexture.size().height * (barrelScale * hitBoxScale))
        barrelSprite.physicsBody = SKPhysicsBody(rectangleOf: contactBox)
        barrelSprite.physicsBody?.isDynamic = false
        barrelSprite.physicsBody?.mass = 1.0
        barrelSprite.physicsBody?.categoryBitMask = barrelCategory
        barrelSprite.physicsBody?.contactTestBitMask = sahilCategory
        barrelSprite.physicsBody?.collisionBitMask = groundCategory
        
        //add to scene
        barrelNode.addChild(barrelSprite)
        //animate
        animateBarrel(sprite: barrelSprite, texture: barrelTexture)
    }
    
    func animateBarrel(sprite: SKSpriteNode, texture: SKTexture) {
        let barrelScale = 0.2 as CGFloat
        let screenWidth = self.frame.size.width
        let distanceOffscreen = 50.0 as CGFloat
        let distanceToMove = screenWidth + distanceOffscreen + texture.size().width
        
        //actions
        let moveBarrel = SKAction.moveBy(x: -distanceToMove, y: 0.0, duration: TimeInterval( screenWidth / groundSpeed))
        let removeBarrel = SKAction.removeFromParent()
        let moveAndRemove = SKAction.sequence([moveBarrel, removeBarrel])
        
        sprite.position = CGPoint(x: distanceToMove, y: getGroundHeight() + (texture.size().height * barrelScale))
        sprite.run(moveAndRemove)
    }
    
    func getGroundHeight() -> CGFloat {
        if let gHeight = groundHeight {
            return gHeight
        } else {
            print("Ground size wasn't previously calculated")
            exit(0)
        }
    }
    
}

// credits to John Kuhn for code references
// credits to StackOverFlow's websites and guidance for assistance with jump mechanics
