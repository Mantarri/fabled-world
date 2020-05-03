module fabled_world;

import godot;

import godot.node;
import godot.opensimplexnoise;
import godot.randomnumbergenerator;

import godot.voxelgenerator;
import godot.voxelbuffer;

import std.math;
import std.file;
import std.conv;
import std.path;


/// Holds all generator code
class CustomGenerator : GodotScript!VoxelGenerator{
    /// VoxelGenerator Channel property
    @Property int channel = VoxelBuffer.Constants.channelType;

    /// Random Number Generator
    @Property Ref!RandomNumberGenerator rng;

    /// Noise for generator
    @Property Ref!OpenSimplexNoise noise;

    /// GDScript _init
    @Method void _init(){
        rng = RandomNumberGenerator._new();
    }

    /// Get used channels
    @Method int getUsedChanoldnelsMask(){
        return 1<<channel;
    }

    /// Generate a block (16x16x16 area)
    @Method void generateBlock(VoxelBuffer voxels, Vector3 origin, int lod){
        Vector3 voxelSize = voxels.getSize();
        for(int z; z < to!int(voxelSize.z); z++){
            for(int x; x < to!int(voxelSize.x); x++){
                for(int y; y < to!int(voxelSize.y); y++){
                    int worldX = to!int(origin.x) + (to!int(x) << lod);
                    int worldY = to!int(origin.y) + (to!int(y) << lod);
                    int worldZ = to!int(origin.z) + (to!int(z) << lod);

                    float n = noise.getNoise3d(worldX, worldY, worldZ);
                    float d = n * noise.period;

                    if(d < 0){
                        voxels.setVoxel(1, x, y, z, VoxelBuffer.Constants.channelType);
                    }

                }
            }
        }
    }

}