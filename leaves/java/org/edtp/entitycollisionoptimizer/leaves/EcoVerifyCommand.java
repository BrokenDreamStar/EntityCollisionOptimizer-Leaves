package org.edtp.entitycollisionoptimizer.leaves;

import ca.spottedleaf.moonrise.patches.chunk_system.level.ChunkSystemLevel;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.util.AbortableIterationConsumer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.AABB;
import org.edtp.entitycollisionoptimizer.natives.CollisionFrame;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;

/**
 * /ecoverify - compares native index query results against the platform (Moonrise) traversal
 * for sample boxes. Set equality is required; order differences are reported because the
 * native index serves vanilla's section traversal while Moonrise iterates chunks z-major.
 */
public final class EcoVerifyCommand {
    private EcoVerifyCommand() {}

    public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
        dispatcher.register(Commands.literal("ecoverify")
                .requires(Commands.hasPermission(Commands.LEVEL_GAMEMASTERS))
                .executes(EcoVerifyCommand::run));
    }

    private static int run(CommandContext<CommandSourceStack> context) {
        CommandSourceStack source = context.getSource();
        int boxes = 0;
        int setMismatches = 0;
        int orderDiffs = 0;
        int entitiesCompared = 0;
        int reported = 0;

        for (ServerLevel level : source.getServer().getAllLevels()) {
            List<AABB> samples = new ArrayList<>();
            for (ServerPlayer player : level.players()) {
                samples.add(player.getBoundingBox().inflate(48.0));
            }
            samples.add(new AABB(-64.0, level.getMinY(), -64.0, 64.0, level.getMaxY(), 64.0));
            int extra = 0;
            for (Entity entity : level.getAllEntities()) {
                if (extra >= 32) {
                    break;
                }
                samples.add(entity.getBoundingBox().inflate(32.0));
                extra++;
            }

            for (AABB box : samples) {
                boxes++;
                List<Entity> platform = new ArrayList<>();
                // Use the limited variant: it is not hooked, so it stays true platform ground truth.
                ((ChunkSystemLevel) level).moonrise$getEntityLookup()
                        .getEntities((Entity) null, box, platform, null, Integer.MAX_VALUE);

                List<Entity> nativeResult = new ArrayList<>();
                CollisionFrame.getEntities(level, box, (AbortableIterationConsumer<Entity>) entity -> {
                    nativeResult.add(entity);
                    return AbortableIterationConsumer.Continuation.CONTINUE;
                });

                entitiesCompared += platform.size();
                List<UUID> platformIds = platform.stream().map(Entity::getUUID).toList();
                List<UUID> nativeIds = nativeResult.stream().map(Entity::getUUID).toList();

                boolean sameSet = platformIds.size() == nativeIds.size()
                        && new HashSet<>(platformIds).equals(new HashSet<>(nativeIds));
                if (!sameSet) {
                    setMismatches++;
                    if (reported++ < 5) {
                        source.sendSuccess(() -> Component.literal("[ecoverify] SET MISMATCH level="
                                + level.dimension().identifier() + " box=" + box
                                + " platform=" + platformIds.size() + " native=" + nativeIds.size()), false);
                    }
                } else if (!platformIds.equals(nativeIds)) {
                    orderDiffs++;
                }
            }
        }

        final int fBoxes = boxes;
        final int fSets = setMismatches;
        final int fOrder = orderDiffs;
        final int fEntities = entitiesCompared;
        source.sendSuccess(() -> Component.literal("[ecoverify] boxes=" + fBoxes
                + " entities=" + fEntities
                + " setMismatch=" + fSets
                + " orderDiff=" + fOrder
                + " servedQueries=" + QueryHookState.served()), false);
        return setMismatches == 0 ? 1 : 0;
    }
}
