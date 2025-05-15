Entity_Manager :: struct {
    MAX_ENTITIES :: 128;

    entities: [MAX_ENTITIES] Entity;
    id_generator: int = 1;

    player_handle: Entity.Handle;
}

ZERO_ENTITY :: Entity.{};
Entity :: struct {
    Handle :: struct {
        id:    int;
        index: int;
    }
    Kind :: enum {
        INVALID;
        PLAYER;
        DROP;
    }

    allocated: bool;

    kind:   Kind;
    handle: Handle;

    has_physics: bool;
    is_visible:  bool;

    texture: *Texture;

    velocity: Vector2;
    position: Vector2;
    size:     Vector2;
}

entity_create :: (using manager: *Entity_Manager, kind: Entity.Kind) -> *Entity {
    index := -1;
    for entities if !it.allocated {
        index = it_index;
        break;
    }
    assert(index >= 0, "Unable to allocate entity, not enough space.");
    entity := *entities[index];
    entity.allocated = true;
    entity.kind      = kind;
    entity.handle    = .{id = id_generator, index = index};
    id_generator += 1;

    if #complete kind == {
      case .INVALID;
        assert(false, "Attempted to allocate entity of kind .NONE");
      case .PLAYER;
        player_setup(entity);
      case .DROP;
        drop_setup(entity);
    }

    return entity;
}

entity_destroy :: (entity: *Entity) {
    // NOTE(mvh): Maybe do more checking???
    entity.* = .{};
}

find :: (using manager: Entity_Manager, handle: Entity.Handle) -> *Entity {
    if handle.id == 0 then return *ZERO_ENTITY;

    entity := *entities[handle.index];
    if entity.handle.id == handle.id then return entity;

    return *ZERO_ENTITY;
}

is_intersecting :: (a: Entity, b: Entity) -> bool {
    a_p0 := a.position - a.size / 2;
    a_p1 := a.position + a.size / 2;

    b_p0 := b.position - b.size / 2;
    b_p1 := b.position + b.size / 2;

    intersecting := a_p0.x < b_p1.x
                 && a_p1.x > b_p0.x
                 && a_p0.y < b_p1.y
                 && a_p1.y > b_p0.y;
    return intersecting;
}

#scope_file

player_setup :: (using entity: *Entity) {
    is_visible = true;
    texture  = *bucket_texture;
    position = .{0.5, 0.05};
    size     = .{0.075, 0.075};
}

drop_setup :: (using entity: *Entity) {
    DROP_GRAVITY :: 0.25;

    has_physics = true;
    is_visible  = true;
    texture  = *drop_texture;
    velocity = .{y = -DROP_GRAVITY};
    position = .{
        x = random_get_zero_to_one() * 0.9 + 0.05,
        y = playfield_height / playfield_width.(float) + size.y * 2,
    };
    size       = .{0.04, 0.04};
}