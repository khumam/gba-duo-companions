// PREVIEW RENDERER — renders a pack's tabs with GBADuo's real companion engine.
//
// Temporary: copy to gba-duo/app/src/test/java/com/khumam/gbaduo/companion/,
// render, look, delete. Don't commit it.
//
//   echo /abs/path/to/my-pack > /tmp/pack-dir.txt        # which pack
//   echo preview-data.json   > /tmp/pack-data.txt        # optional, which snapshot
//   echo battle              > /tmp/pack-pages.txt       # optional, extra pages to open
//   JAVA_HOME=<JDK 17+> ./gradlew :app:testDebugUnitTest --tests '*PreviewRender' --rerun
//   open /tmp/pack-preview                                # screen-N.png, tall-N.png
//
// screen-N = the Thor's companion screen (1240x1080 px landscape, 369 dpi = ~538x468dp)
// per tab; tall-N = the whole
// scrolling page. CSS/layout/tree warnings print to the test output (-i).
// Gradle needs JDK 17 (a portable Temurin in /tmp is enough). It draws the
// decor view itself because captureToImage() times out under Robolectric here,
// and --rerun is needed because Gradle doesn't track the pack folder.

package com.khumam.gbaduo.companion

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.activity.ComponentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import com.khumam.gbaduo.companion.android.AndroidCompanionPlatform
import com.khumam.gbaduo.companion.style.CssParser
import com.khumam.gbaduo.companion.tree.CompanionNode
import com.khumam.gbaduo.companion.tree.CompanionTree
import com.khumam.gbaduo.companion.ui.CompanionScreen
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import androidx.compose.ui.graphics.Color as ComposeColor

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PreviewRender {

    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val packDir = File(File("/tmp/pack-dir.txt").readText().trim())
    private val dataFile = File("/tmp/pack-data.txt").takeIf { it.isFile }?.readText()?.trim() ?: "preview-data.json"
    private val out = File("/tmp/pack-preview").apply { mkdirs() }

    // The tab bar is the first node whose children are all tappable.
    private fun findTabs(node: CompanionNode): CompanionNode? {
        if (node.children.size >= 2 && node.children.all { it.onClick != null }) return node
        return node.children.firstNotNullOfOrNull { findTabs(it) }
    }

    private fun render(prefix: String) {
        val manifest = PackManifest.parse(File(packDir, "manifest.json").readText())
        val builtIn = CssParser.parse(File("src/main/assets/${PackStyles.BUILT_IN_ASSET}").readText())
        val styles = PackStyles.forPack(manifest, packDir)
        styles.forEach { if (it.warnings.isNotEmpty()) println("CSS WARN: ${it.warnings}") }
        val layout = LayoutParser.parseWithWarnings(File(packDir, manifest.layoutFile).readText())
        if (layout.warnings.isNotEmpty()) println("LAYOUT WARN: ${layout.warnings}")
        val platform = AndroidCompanionPlatform(packDir, (listOf(builtIn) + styles).flatMap { it.fontFaces })
        val tree = CompanionTree(layout.root, listOf(builtIn), styles, platform::loadImage)
        tree.update(JsonTree.parseObject(File(packDir, dataFile).readText()))
        compose.setContent {
            Box(Modifier.fillMaxSize().background(ComposeColor.Black)) { CompanionScreen(tree, platform) }
        }
        compose.waitForIdle()
        val tabs = compose.runOnIdle { findTabs(tree.root) }
        for (i in 0 until (tabs?.children?.size ?: 1)) {
            if (tabs != null) compose.runOnUiThread { tabs.children[i].onClick!!.invoke() }
            compose.waitForIdle()
            if (tree.warnings.isNotEmpty()) println("TREE WARN: ${tree.warnings}")
            val bmp = compose.runOnUiThread {
                val v = compose.activity.window.decorView
                Bitmap.createBitmap(v.width, v.height, Bitmap.Config.ARGB_8888).also { v.draw(Canvas(it)) }
            }
            File(out, "$prefix-$i.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        // Other `pages` (e.g. a battle page the script opens): one name per line in
        // /tmp/pack-pages.txt; navigated the way update()'s `ui` entry does it.
        val pages = File("/tmp/pack-pages.txt").takeIf { it.isFile }?.readLines()?.map { it.trim() }?.filter { it.isNotEmpty() }.orEmpty()
        for (page in pages) {
            val warnings = mutableListOf<String>()
            @Suppress("UNCHECKED_CAST")
            val data = JsonTree.parseObject(File(packDir, dataFile).readText()) as Map<String, Any?>
            compose.runOnUiThread { tree.updateFromScript(data + ("ui" to mapOf("navigate" to page)), warnings) }
            compose.waitForIdle()
            if (warnings.isNotEmpty()) println("UI WARN: $warnings")
            val bmp = compose.runOnUiThread {
                val v = compose.activity.window.decorView
                Bitmap.createBitmap(v.width, v.height, Bitmap.Config.ARGB_8888).also { v.draw(Canvas(it)) }
            }
            File(out, "$prefix-$page.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }

    @Test
    @Config(sdk = [34], qualifiers = "w538dp-h468dp-land-369dpi")
    fun screen() = render("screen")

    @Test
    @Config(sdk = [34], qualifiers = "w538dp-h1400dp-369dpi")
    fun tall() = render("tall")
}
