package org.edtp.entitycollisionoptimizer;

import com.mojang.logging.LogUtils;
import org.slf4j.Logger;

/** Logger holder shared by all loaders; the Fabric entry class is excluded from the Leaves plugin build. */
public final class EcoLog {
    public static final Logger LOGGER = LogUtils.getLogger();

    private EcoLog() {}
}
