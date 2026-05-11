import * as React from "react"

const Separator = React.forwardRef(
  ({ className, orientation = "horizontal", decorative = true, ...props }, ref) => (
    <div
      ref={ref}
      className={`shrink-0 bg-slate-200 ${
        orientation === "vertical" ? "h-full w-px" : "h-px w-full"
      } ${className || ''}`}
      {...props}
    />
  )
)
Separator.displayName = "Separator"

export { Separator }
