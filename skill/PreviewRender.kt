// PREVIEW RENDERER — renders a pack with GBADuo's real companion engine (the same
// CssParser / StyleResolver / CompanionTree / CompanionScreen the Thor runs), under
// Robolectric, so a pack can be looked at on a Mac without the device.
//
// Don't run this by hand: `preview-pack.sh` (same folder) copies it into the app repo's
// tests, writes the config below, runs Gradle, copies the PNGs out and deletes it again.
// It is a temporary test: never commit it to the app repo.
//
// Config: app/build/preview-in/config.properties (written by the script)
//   pack=/abs/path/to/pack          data=preview-data.json (relative to the pack, or absolute)
//   out=/abs/path/to/out            pages=battle,detail   (extra `pages` names, comma separated)
//   nav=dock                        class of the nav node (default: the biggest all-tappable group)
//
// Output in `out`:
//   screen-<n>.png      the Thor's companion screen (1240x1080 px, 369 dpi = 538x468 dp), one per
//                       tab/nav button, in order (the first node whose children are all tappable)
//   screen-<page>.png   each extra page from `pages`, navigated like update()'s `ui` entry
//   tall-<n>.png        same tabs on a 538 x 1400 dp canvas, to see content that overflows
//   report.txt          CSS / layout / tree / ui warnings, the page and tab count, image sizes
//
// Why not captureToImage(): it times out under Robolectric here, so the decor view is drawn
// into a bitmap directly. Pixel size is real device size, so screenshots compare 1:1 with
// the pack's `screenshoots/*.png` taken on the Thor.

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
import java.util.Properties
import androidx.compose.ui.graphics.Color as ComposeColor

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PreviewRender {

    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val config = Properties().apply {
        File("build/preview-in/config.properties").inputStream().use { load(it) }
    }
    private val packDir = File(config.getProperty("pack"))
    private val dataPath = config.getProperty("data", "preview-data.json")
    private val dataFile = File(dataPath).takeIf { it.isAbsolute } ?: File(packDir, dataPath)
    private val out = File(config.getProperty("out")).apply { mkdirs() }
    private val extraPages = config.getProperty("pages", "").split(",").map { it.trim() }.filter { it.isNotEmpty() }
    private val report = StringBuilder()

    private fun note(line: String) { println(line); report.appendLine(line) }

    // The nav: the node with class `nav` from the config if given, else the node with the most
    // children that are all tappable (dock, tab bar, nav bar). Lists of tappable rows or
    // WORLD/DUNGEON switches have fewer buttons than the page nav, so they lose.
    private val navClass = config.getProperty("nav", "").trim()

    private fun findTabs(node: CompanionNode): CompanionNode? {
        val all = generateSequence(listOf(node)) { level -> level.flatMap { it.children }.takeIf { it.isNotEmpty() } }
            .flatten()
        if (navClass.isNotEmpty()) return all.firstOrNull { navClass in it.style.classes && it.children.isNotEmpty() }
        return all.filter { it.children.size >= 2 && it.children.all { c -> c.onClick != null } }
            .maxByOrNull { it.children.size }
    }

    private fun snapshot(name: String) {
        val bmp = compose.runOnUiThread {
            val v = compose.activity.window.decorView
            Bitmap.createBitmap(v.width, v.height, Bitmap.Config.ARGB_8888).also { v.draw(Canvas(it)) }
        }
        File(out, "$name.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        note("wrote $name.png ${bmp.width}x${bmp.height}")
    }

    private fun render(prefix: String) {
        val manifest = PackManifest.parse(File(packDir, "manifest.json").readText())
        val builtIn = CssParser.parse(File("src/main/assets/${PackStyles.BUILT_IN_ASSET}").readText())
        val styles = PackStyles.forPack(manifest, packDir)
        styles.forEach { if (it.warnings.isNotEmpty()) note("CSS WARN: ${it.warnings}") }
        val layout = LayoutParser.parseWithWarnings(File(packDir, manifest.layoutFile).readText())
        if (layout.warnings.isNotEmpty()) note("LAYOUT WARN: ${layout.warnings}")
        val platform = AndroidCompanionPlatform(packDir, (listOf(builtIn) + styles).flatMap { it.fontFaces })
        val tree = CompanionTree(layout.root, listOf(builtIn), styles, platform::loadImage)
        val data = JsonTree.parseObject(dataFile.readText())
        tree.update(data)
        compose.setContent {
            Box(Modifier.fillMaxSize().background(ComposeColor.Black)) { CompanionScreen(tree, platform) }
        }
        compose.waitForIdle()
        val tabs = compose.runOnIdle { findTabs(tree.root) }
        note("$prefix: ${tabs?.children?.size ?: 0} nav buttons")
        for (i in 0 until (tabs?.children?.size ?: 1)) {
            if (tabs != null) compose.runOnUiThread { tabs.children[i].onClick!!.invoke() }
            compose.waitForIdle()
            if (tree.warnings.isNotEmpty()) note("TREE WARN: ${tree.warnings}")
            snapshot("$prefix-$i")
        }
        // Pages the script opens by itself (battle, detail): navigated the way update()'s
        // `ui` entry does it. Reuses the same data, so put what the page shows in the data file.
        @Suppress("UNCHECKED_CAST")
        val dataMap = data as Map<String, Any?>
        for (page in extraPages) {
            val warnings = mutableListOf<String>()
            compose.runOnUiThread { tree.updateFromScript(dataMap + ("ui" to mapOf("navigate" to page)), warnings) }
            compose.waitForIdle()
            if (warnings.isNotEmpty()) note("UI WARN ($page): $warnings")
            snapshot("$prefix-$page")
        }
    }

    private fun finish() = File(out, "report.txt").appendText(report.toString().also { report.clear() })

    // The Thor's companion screen: 1240 x 1080 px at 369 dpi (2.30625 px/dp) = 538 x 468 dp.
    @Test
    @Config(sdk = [34], qualifiers = "w538dp-h468dp-land-369dpi")
    fun screen() { render("screen"); finish() }

    // Same pack on a tall canvas, for content that scrolls or overflows.
    @Test
    @Config(sdk = [34], qualifiers = "w538dp-h1400dp-369dpi")
    fun tall() { render("tall"); finish() }
}
