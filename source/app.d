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

    /// List of references to biomes
    @Property Array biomes;

    /// GDScript _init
    @Method void _init(){
        rng = RandomNumberGenerator._new();
    }

    /// Get used channels
    @Method int getUsedChannelsMask(){
        return (1 << channel);
    }

    this() { biomes = Array.make(); }

    /// Generate a block (16x16x16 area)
    @Method void generateBlock(VoxelBuffer voxels, Vector3 origin, int lod){
        for(int z; z < to!int(voxels.getSizeZ()); z++){
            for(int x; x < to!int(voxels.getSizeX()); x++){
                for(int y; y < to!int(voxels.getSizeY()); y++){
                    float worldX = origin.x + (x << lod);
                    float worldY = origin.y + (y << lod);
                    float worldZ = origin.z + (z << lod);

                    float shapedNoise = noise.getNoise3d(worldX, worldY, worldZ);
                    float shapedNoiseUse = shapedNoise * noise.period;
                    
                    if(shapedNoiseUse < 0 && worldY < 256){
                        voxels.setVoxel(1, to!int(x), to!int(y), to!int(z), channel);
                    }else if(worldY <= 0){
                        voxels.setVoxel(1, to!int(x), to!int(y), to!int(z), channel);
                    }
                }
            }
        }
    }

}