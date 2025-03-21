/* font-manager-reject.h
 *
 * Copyright (C) 2009-2025 Jerry Casiano
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.
 *
 * If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
*/

#pragma once

#include "font-manager-database.h"
#include "font-manager-database-iterator.h"
#include "font-manager-selections.h"
#include "font-manager-string-set.h"
#include "font-manager-utils.h"

#define FONT_MANAGER_TYPE_REJECT (font_manager_reject_get_type ())
G_DECLARE_DERIVABLE_TYPE(FontManagerReject, font_manager_reject, FONT_MANAGER, REJECT, FontManagerSelections)

struct _FontManagerRejectClass
{
    FontManagerSelectionsClass parent_instance;
};

FontManagerReject * font_manager_reject_new (void);
FontManagerStringSet * font_manager_reject_get_rejected_files (FontManagerReject *self, FontManagerDatabase *db, GError **error);

