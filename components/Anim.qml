import QtQuick
import "../core"

// Motion primitive. Call sites pick a semantic type -- Anim { type: Anim.FastEffects }
// -- instead of hardcoding a duration and curve, so the whole shell retimes from
// Tokens alone.
NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        const d = Tokens.anim.durations;
        switch (type) {
        case Anim.FastSpatial:
            return d.expressiveFastSpatial;
        case Anim.DefaultSpatial:
            return d.expressiveDefaultSpatial;
        case Anim.SlowSpatial:
            return d.expressiveSlowSpatial;
        case Anim.FastEffects:
            return d.expressiveFastEffects;
        case Anim.DefaultEffects:
            return d.expressiveDefaultEffects;
        case Anim.SlowEffects:
            return d.expressiveSlowEffects;
        }
        if (type < Anim.StandardSmall || type > Anim.EmphasizedExtraLarge)
            return d.normal;
        // The eight standard/emphasized types share one small->extraLarge ramp.
        return d[["small", "normal", "large", "extraLarge"][type % 4]];
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        const a = Tokens.anim;
        switch (type) {
        case Anim.FastSpatial:
            return a.expressiveFastSpatial;
        case Anim.DefaultSpatial:
            return a.expressiveDefaultSpatial;
        case Anim.SlowSpatial:
            return a.expressiveSlowSpatial;
        case Anim.FastEffects:
            return a.expressiveFastEffects;
        case Anim.DefaultEffects:
            return a.expressiveDefaultEffects;
        case Anim.SlowEffects:
            return a.expressiveSlowEffects;
        }
        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return a.emphasized;
        return a.standard;
    }
}
