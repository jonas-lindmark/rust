use rustc_abi::Endian;

use crate::spec::{
    base, Cc, LinkerFlavor, Lld, StackProbeType, Target, TargetMetadata, TargetOptions,
};

pub(crate) fn target() -> Target {
    let mut base = base::netbsd::opts();
    base.add_pre_link_args(LinkerFlavor::Gnu(Cc::Yes, Lld::No), &[]);
    base.max_atomic_width = Some(32);
    base.cpu = "M68030".into();
    base.stack_probes = StackProbeType::Inline;

    Target {
        llvm_target: "m68k-unknown-netbsd".into(),
        metadata: TargetMetadata {
            description: Some("NetBSD Motorola 680x0".into()),
            tier: Some(3),
            host_tools: Some(true),
            std: Some(true),
        },
        pointer_width: 32,
        data_layout: "E-m:e-p:32:16:32-i8:8:8-i16:16:16-i32:16:32-n8:16:32-a:0:32-S32".into(),
        arch: "m68k".into(),
        options: TargetOptions { endian: Endian::Big, mcount: "__mcount".into(), ..base },
    }
}
