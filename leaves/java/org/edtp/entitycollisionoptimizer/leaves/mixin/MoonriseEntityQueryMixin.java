package org.edtp.entitycollisionoptimizer.leaves.mixin;

import ca.spottedleaf.moonrise.patches.chunk_system.level.entity.EntityLookup;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.AbortableIterationConsumer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.entity.EntityTypeTest;
import net.minecraft.world.phys.AABB;
import org.edtp.entitycollisionoptimizer.leaves.QueryHookState;
import org.edtp.entitycollisionoptimizer.natives.CollisionFrame;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import java.util.List;
import java.util.function.Consumer;
import java.util.function.Predicate;

/**
 * Leaves/Moonrise replacement for the Fabric build's EntitySectionStorage hook: serves the
 * engine's entity box queries from the native index.
 *
 * <p>On Moonrise the engine funnels through the LevelEntityGetter compatibility methods
 * (get(TypeTest, AABB, consumer) / get(AABB, Consumer)) and, far more frequently, through the
 * list-shaped lookup methods that Level calls directly for getEntities/getEntitiesOfClass.
 * Both layers are covered here. The limited (maxCount) variants stay platform-served.</p>
 */
@Mixin(value = EntityLookup.class, priority = 1100)
public abstract class MoonriseEntityQueryMixin {
    private static boolean eco$gate(EntityLookup lookup) {
        Level world = lookup.world;
        return world instanceof ServerLevel level
                && QueryHookState.enabled()
                && CollisionFrame.queriesEnabled(level);
    }

    private static ServerLevel eco$level(EntityLookup lookup) {
        return (ServerLevel) lookup.world;
    }

    /* LevelEntityGetter compatibility layer */

    @Inject(
            method = "get(Lnet/minecraft/world/level/entity/EntityTypeTest;Lnet/minecraft/world/phys/AABB;Lnet/minecraft/util/AbortableIterationConsumer;)V",
            at = @At("HEAD"),
            cancellable = true
    )
    private void eco$nativeTypedQuery(
            EntityTypeTest<Entity, ?> type,
            AABB box,
            AbortableIterationConsumer<?> consumer,
            CallbackInfo ci
    ) {
        EntityLookup self = (EntityLookup) (Object) this;
        if (!eco$gate(self)) {
            return;
        }
        QueryHookState.countServed();
        CollisionFrame.getEntities(eco$level(self), type, box, consumer);
        ci.cancel();
    }

    @Inject(
            method = "get(Lnet/minecraft/world/phys/AABB;Ljava/util/function/Consumer;)V",
            at = @At("HEAD"),
            cancellable = true
    )
    private void eco$nativeUntypedQuery(AABB box, Consumer<Entity> consumer, CallbackInfo ci) {
        EntityLookup self = (EntityLookup) (Object) this;
        if (!eco$gate(self)) {
            return;
        }
        QueryHookState.countServed();
        CollisionFrame.getEntities(eco$level(self), box, (AbortableIterationConsumer<Entity>) entity -> {
            consumer.accept(entity);
            return AbortableIterationConsumer.Continuation.CONTINUE;
        });
        ci.cancel();
    }

    /* Engine list-shaped funnel used by Level#getEntities and Level#getEntitiesOfClass */

    @Inject(
            method = "getEntities(Lnet/minecraft/world/entity/Entity;Lnet/minecraft/world/phys/AABB;Ljava/util/List;Ljava/util/function/Predicate;)V",
            at = @At("HEAD"),
            cancellable = true
    )
    private void eco$nativeUntypedList(
            Entity except,
            AABB box,
            List<?> into,
            Predicate<?> predicate,
            CallbackInfo ci
    ) {
        EntityLookup self = (EntityLookup) (Object) this;
        if (!eco$gate(self)) {
            return;
        }
        QueryHookState.countServed();
        CollisionFrame.getEntities(eco$level(self), box, (AbortableIterationConsumer<Entity>) entity -> {
            if (entity != except && (predicate == null || ((Predicate<Entity>) predicate).test(entity))) {
                ((List<Entity>) into).add(entity);
            }
            return AbortableIterationConsumer.Continuation.CONTINUE;
        });
        ci.cancel();
    }

    @Inject(
            method = "getEntities(Lnet/minecraft/world/entity/EntityType;Lnet/minecraft/world/phys/AABB;Ljava/util/List;Ljava/util/function/Predicate;)V",
            at = @At("HEAD"),
            cancellable = true
    )
    private void eco$nativeByTypeList(
            EntityType<?> type,
            AABB box,
            List<?> into,
            Predicate<?> predicate,
            CallbackInfo ci
    ) {
        EntityLookup self = (EntityLookup) (Object) this;
        if (!eco$gate(self)) {
            return;
        }
        QueryHookState.countServed();
        // EntityType itself is the exact-type EntityTypeTest.
        CollisionFrame.getEntities(eco$level(self), (EntityTypeTest) type, box, (AbortableIterationConsumer<Object>) casted -> {
            if (predicate == null || ((Predicate<Object>) predicate).test(casted)) {
                ((List<Object>) into).add(casted);
            }
            return AbortableIterationConsumer.Continuation.CONTINUE;
        });
        ci.cancel();
    }

    @Inject(
            method = "getEntities(Ljava/lang/Class;Lnet/minecraft/world/entity/Entity;Lnet/minecraft/world/phys/AABB;Ljava/util/List;Ljava/util/function/Predicate;)V",
            at = @At("HEAD"),
            cancellable = true
    )
    private void eco$nativeByClassList(
            Class<?> clazz,
            Entity except,
            AABB box,
            List<?> into,
            Predicate<?> predicate,
            CallbackInfo ci
    ) {
        EntityLookup self = (EntityLookup) (Object) this;
        if (!eco$gate(self)) {
            return;
        }
        QueryHookState.countServed();
        CollisionFrame.getEntities(eco$level(self), EntityTypeTest.forClass((Class) clazz), box, (AbortableIterationConsumer<Object>) casted -> {
            if (casted != except && (predicate == null || ((Predicate<Object>) predicate).test(casted))) {
                ((List<Object>) into).add(casted);
            }
            return AbortableIterationConsumer.Continuation.CONTINUE;
        });
        ci.cancel();
    }
}
