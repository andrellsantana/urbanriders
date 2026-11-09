extends RefCounted
## Funde os MeshInstance3D filhos diretos de um nó em uma única malha com cor por vértice
## (uma chamada de desenho + contorno), preservando a aparência Cel Shading. Usado nos ciclistas.

const Toon := preload("res://scripts/core/toon_materials.gd")


static func merge_children(container: Node3D, exclude: Array = [], outline_width: float = 0.018) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
	var merged: Array[MeshInstance3D] = []
	var shadow := false
	for c in container.get_children():
		if not (c is MeshInstance3D) or exclude.has(c):
			continue
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var color := Color.WHITE
		var mat := mi.material_override
		if mat is ShaderMaterial:
			color = (mat as ShaderMaterial).get_shader_parameter("albedo")
		elif mat is StandardMaterial3D:
			color = (mat as StandardMaterial3D).albedo_color
		var xf := mi.transform
		var nb := xf.basis.inverse().transposed()
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var order: PackedInt32Array = idx
			if order.is_empty():
				order.resize(verts.size())
				for i in verts.size():
					order[i] = i
			for i in order:
				var n := (nb * norms[i]).normalized()
				st.set_color(color)
				st.set_normal(n)
				st.set_custom(0, Color(n.x, n.y, n.z))
				st.add_vertex(xf * verts[i])
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow = true
		merged.append(mi)
	if merged.is_empty():
		return null
	for mi in merged:
		container.remove_child(mi)
		mi.queue_free()
	var out := MeshInstance3D.new()
	out.name = "Fundido"
	out.mesh = st.commit()
	out.material_override = Toon.make(Color.WHITE, Toon.Outline.CUSTOM, outline_width, true)
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	container.add_child(out)
	return out
