package org.edtp.entitycollisionoptimizer.leaves.mixin;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import org.edtp.entitycollisionoptimizer.commands.CollisionOptimizerCommand;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import java.util.concurrent.atomic.AtomicBoolean;

/** Leaves bootstrap (replaces Fabric's CommandRegistrationCallback): registers /eco with the server dispatcher. */
@Mixin(Commands.class)
public abstract class LeavesCommandsMixin {
    @Shadow public abstract CommandDispatcher<CommandSourceStack> getDispatcher();

    @Unique private static final AtomicBoolean eco$registered = new AtomicBoolean();

    @Inject(
            method = "<init>(Lnet/minecraft/commands/Commands$CommandSelection;Lnet/minecraft/commands/CommandBuildContext;)V",
            at = @At("RETURN")
    )
    private void eco$registerCommands(CallbackInfo ci) {
        eco$tryRegister();
    }

    @Inject(
            method = "<init>(Lnet/minecraft/commands/Commands$CommandSelection;Lnet/minecraft/commands/CommandBuildContext;Z)V",
            at = @At("RETURN")
    )
    private void eco$registerCommandsWithFlag(CallbackInfo ci) {
        eco$tryRegister();
    }

    @Unique
    private void eco$tryRegister() {
        if (eco$registered.compareAndSet(false, true)) {
            CollisionOptimizerCommand.register(this.getDispatcher());
        }
    }
}
