package team.starm.eco.leaves;

import org.bukkit.plugin.java.JavaPlugin;

/**
 * Dormant Bukkit entry point for the Leaves plugin descriptor. All behaviour is
 * implemented through the mixins listed in leaves-plugin.json.
 *
 * <p>Lives outside the extraction prefix on purpose: leavesclip puts every class under
 * the {@code mixin.package-name} prefix onto the launcher classpath first, and Bukkit
 * refuses to construct a JavaPlugin that was not loaded by a plugin class loader.</p>
 */
public final class EcoLeavesPlugin extends JavaPlugin {
}
