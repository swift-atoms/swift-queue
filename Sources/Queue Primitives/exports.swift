// exports.swift
// Umbrella per [MOD-005]: re-exports the PACKAGE'S OWN type module so a single
// `import Queue_Primitives` surfaces the whole package. Per the exports-narrowing
// ruling (audit #9, 2026-06-10), no EXTERNAL modules are re-exported — consumers
// import the column-vocabulary modules explicitly.

@_exported public import Queue_Primitive
