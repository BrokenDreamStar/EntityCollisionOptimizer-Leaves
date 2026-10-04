package org.edtp.entitycollisionoptimizer.leaves;

import java.util.concurrent.atomic.AtomicLong;

/** Runtime state of the Leaves native query hook. Disable with -Deco.queryHook=false. */
public final class QueryHookState {
    private static final boolean ENABLED =
            !"false".equalsIgnoreCase(System.getProperty("eco.queryHook", "true"));
    private static final AtomicLong SERVED = new AtomicLong();

    public static boolean enabled() {
        return ENABLED;
    }

    public static void countServed() {
        SERVED.incrementAndGet();
    }

    public static long served() {
        return SERVED.get();
    }

    private QueryHookState() {}
}
