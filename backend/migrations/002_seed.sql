-- Seed default categories (user_id NULL = global, accessible by all users)
INSERT INTO categories (name, type, icon, color, is_default) VALUES
('Gaji',        'income',  '💼', '#22C55E', TRUE),
('Bonus',       'income',  '⭐', '#10B981', TRUE),
('Investasi',   'income',  '📈', '#059669', TRUE),
('Penjualan',   'income',  '💸', '#16A34A', TRUE),
('Freelance',   'income',  '💻', '#15803D', TRUE),
('Lainnya',     'income',  '➕', '#166534', TRUE),
('Makanan',     'expense', '🍔', '#EF4444', TRUE),
('Transport',   'expense', '🚗', '#F97316', TRUE),
('Belanja',     'expense', '🛒', '#EAB308', TRUE),
('Tagihan',     'expense', '📄', '#8B5CF6', TRUE),
('Kesehatan',   'expense', '🏥', '#EC4899', TRUE),
('Hiburan',     'expense', '🎬', '#06B6D4', TRUE),
('Pendidikan',  'expense', '🎓', '#3B82F6', TRUE),
('Investasi',   'expense', '💰', '#6366F1', TRUE),
('Cicilan',     'expense', '💳', '#DC2626', TRUE),
('Lainnya',     'expense', '📦', '#6B7280', TRUE)
ON CONFLICT DO NOTHING;
