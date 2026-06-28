export type ThemeId = 'default' | 'sakura' | 'neon' | 'forest' | 'ocean'

export interface Theme {
  id: ThemeId
  label: string
  emoji: string
  preview: string
}

export const THEMES: Theme[] = [
  { id: 'default', label: 'Default',  emoji: '⬜', preview: '#18181b' },
  { id: 'sakura',  label: 'Sakura',   emoji: '🌸', preview: '#ec4899' },
  { id: 'neon',    label: 'Neon',     emoji: '⚡', preview: '#22c55e' },
  { id: 'forest',  label: 'Forest',   emoji: '🌿', preview: '#15803d' },
  { id: 'ocean',   label: 'Ocean',    emoji: '🌊', preview: '#0891b2' },
]
