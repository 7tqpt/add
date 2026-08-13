import React from 'react'
import type { ComponentType } from 'react'

type LucideLike = ComponentType<{ size?: number; className?: string; strokeWidth?: number; 'aria-hidden'?: boolean }>

export function Icon({
  icon: IconComp,
  size = 18,
  strokeWidth = 1.5,
  className = '',
  animated = false,
  ...props
}: {
  icon: LucideLike
  size?: number
  strokeWidth?: number
  className?: string
  animated?: boolean
  [k: string]: any
}) {
  const animClass = animated ? 'icon-anim' : ''
  return (
    <IconComp
      size={size}
      strokeWidth={strokeWidth}
      aria-hidden
      className={`${className} ${animClass}`.trim()}
      {...props}
    />
  )
}
