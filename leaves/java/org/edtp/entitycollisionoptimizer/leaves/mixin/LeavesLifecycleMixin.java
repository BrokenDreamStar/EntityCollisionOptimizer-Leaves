package org.edtp.entitycollisionoptimizer.leaves.mixin;

import net.minecraft.server.MinecraftServer;
import org.edtp.entitycollisionoptimizer.natives.CollisionFrame;
import org.edtp.entitycollisionoptimizer.natives.FFMBackend;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Leaves bootstrap (replaces Fabric's SERVER_STOPPING event): releases the native collision state. */
@Mixin(MinecraftServer.class)
public abstract class LeavesLifecycleMixin {
    @Inject(method = "stopServer", at = @At("HEAD"))
    private void eco$releaseNativeState(CallbackInfo ci) {
        CollisionFrame.destroy();
        FFMBackend.destroy();
    }
}
