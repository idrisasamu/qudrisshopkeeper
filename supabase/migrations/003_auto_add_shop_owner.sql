-- ================================================
-- Auto-add shop owner to staff table
-- ================================================
-- This trigger automatically adds the shop creator as an owner in the staff table

-- Function to auto-add owner after shop creation
CREATE OR REPLACE FUNCTION public.auto_add_shop_owner()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER 
AS $$
BEGIN
  -- Insert the shop creator as owner in staff table
  INSERT INTO public.staff (
    shop_id, 
    user_id, 
    role, 
    is_active, 
    created_by, 
    updated_by,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.created_by,
    'owner',
    true,
    NEW.created_by,
    NEW.created_by,
    NOW(),
    NOW()
  )
  ON CONFLICT (shop_id, user_id, deleted_at) DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_auto_add_shop_owner ON public.shops;
CREATE TRIGGER trigger_auto_add_shop_owner
  AFTER INSERT ON public.shops
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_add_shop_owner();

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

COMMENT ON FUNCTION public.auto_add_shop_owner IS 'Automatically adds shop creator as owner in staff table';

