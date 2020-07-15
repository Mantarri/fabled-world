module fabled_world;

import godot;

import godot.node;
import godot.resource;
import godot.noise.all;
import godot.randomnumbergenerator;
import godot.resourceloader;

import godot.voxelgenerator;
import godot.voxelbuffer;

import std.math;
import std.file;
import std.conv;
import std.path;
import std.traits : EnumMembers;

/// Biomes Temperatures
enum BiomeTemps : float {
    MIN = -1.0f,
    COLD = -1.0f,
    COOL = -1.0f,
    NORMAL = 0.0f,
    WARM = 0.0f,
    HOT = 0.0f,
    BURNING = 0.0f,
    MAX = 1.0f
}

/// Biome Humidity zones
enum BiomeHumidities : float {
    MIN = -1.0f,
    DRY = -1.0f,
    DESERT = -1.0f,
    SLIGHT = -1.0f,
    MODERATE = 0.0f,
    VERY = 0.0f,
    EXTREME = 1.0f,
    MAX = 1.0f
}


/// Holds all generator code
class CustomGenerator : GodotScript!VoxelGenerator{
    /// Holds biome placement noise points
    /// And calculates distance to closest valid biome
    struct BiomePoints{
        /// Temperature value for given XYZ
        float temperatureNoise;
        
        /// humidity value for given XYZ
        float humidityNoise;

        /// Altitude noise (unused currently)
        //float altitudeNoise;

        /// Get distance from biome to temperature + humidity point
        float calculateDistanceTo(float biomeTemperature, float biomeHumidity){
            return(sqrt(pow(biomeTemperature - temperatureNoise, 2) +
            pow(biomeHumidity - humidityNoise, 2) * 1.0));
        }
    }

    /// VoxelGenerator Channel property
    @Property VoxelBuffer.ChannelId channel = VoxelBuffer.ChannelId.channelType;

    /// Random Number Generator
    @Property Ref!RandomNumberGenerator rng;

    /// Noise for generator
    @Property Ref!FastNoiseSIMD terrainNoise;

    /// Noise for moisture map
    @Property Ref!FastNoiseSIMD temperatureNoise;

    /// Humidity noise
    @Property Ref!FastNoiseSIMD humidityNoise;

    /// Block for generation
    @Property int placementBlock;

    /// List of references to biomes
    @Property Array biomes;

    /// Make sure `biomes` array is useable
    this() { biomes = Array.make(); }

    int currentBiome = -1;

    /// GDScript _init
    @Method void _init(){
        rng = RandomNumberGenerator._new();
    }

    /// Get used channels
    @Method int getUsedChannelsMask(){
        return (1 << channel);
    }

    /// Used to linearly interpolate bias
    float lerp(float p_from, float p_to, float p_weight) {
        return p_from + (p_to - p_from) * p_weight;
    }

    /// Inverse Linear interpolate
    float inverse_lerp(float p_from, float p_to, float p_value) {
        return(p_value - p_from) / (p_to - p_from);
    }

    /// Get value for y pos in reference to biome min & max
    /// As a float ranging from -1 to +1
    float getYBias(float y, float heightMin, float heightMax){
        const float t = inverse_lerp(heightMin, heightMax, y);
        return(lerp(0, 1, t));
    }

    /// Place blocks for block (16x16x16 area)
    void placeBlock(float[16][16][16] blocks, VoxelBuffer voxels){
        foreach(x; 0..16) foreach(y; 0..16) foreach(z; 0..16){
            if(blocks[x][y][z] < 0){
                if(humidityNoise.getNoise2d(x, z) > 0){
                    placementBlock = 1;
                }else{
                    placementBlock = 2;
                }
                voxels.setVoxel(placementBlock, x, y, z, channel);
            }
        }
    }

    /// Generate a block (16x16x16 area)
    @Method void generateBlock(VoxelBuffer voxels, Vector3 origin, int lod){
        /// Position of noise value to get from noise array set
        int terrainNoiseArrayPos = 0;
        int temperatureArrayPos = 0;
        int humidityNoiseArrayPos = 0;
        Ref!Resource biome;
        float heightMax;
        float heightMin;

        /// 1-dimensional array storing 16x16x16 block of terrain noise, read order is X, Y, Z
        const PoolRealArray terrainNoiseSet = terrainNoise.getNoiseSet3dv(
            Vector3(origin.x, origin.y, origin.z),
            Vector3(voxels.getSizeX(), voxels.getSizeY(), voxels.getSizeZ())
            );

        /// 1-dimensional array storing 16x16x16 block of temperature noise, read order is X, Y, Z
        const PoolRealArray temperatureNoiseSet = temperatureNoise.getNoiseSet3dv(
            Vector3(origin.x, origin.y, origin.z),
            Vector3(voxels.getSizeX(), voxels.getSizeY(), voxels.getSizeZ())
            );
            
        /// 1-dimensional array storing 16x16x16 block of humidity noise, read order is X, Y, Z
        const PoolRealArray humidityNoiseSet = humidityNoise.getNoiseSet3dv(
            Vector3(origin.x, origin.y, origin.z),
            Vector3(voxels.getSizeX(), voxels.getSizeY(), voxels.getSizeZ())
            );

        for(int x; x < voxels.getSizeX(); x++){
            for(int y; y < voxels.getSizeY(); y++){
                for(int z; z < voxels.getSizeZ(); z++){
                    const float worldX = origin.x + (x << lod);
                    const float worldY = origin.y + (y << lod);
                    const float worldZ = origin.z + (z << lod);
                    float min = float.infinity;

                    const float temperature = temperatureNoiseSet[temperatureArrayPos];
                    const float humidity = humidityNoiseSet[humidityNoiseArrayPos];
                    
                    BiomePoints biomePoints;
                    biomePoints.temperatureNoise = temperature;
                    biomePoints.humidityNoise = humidity;
                    /// Biome ID
                    int bid = -1;

                    for(int i; i < biomes.size(); i++){
                        const Ref!Resource b = biomes[i].as!Resource;
                        const float t = [EnumMembers!BiomeTemps][b.get(gs!"temperature").as!int];
                        const float h = [EnumMembers!BiomeHumidities][b.get(gs!"humidity").as!int];
                        const float distance = biomePoints.calculateDistanceTo(t, h);
                        //print(gs!"Distance: ", distance);
                        
                        if(min > distance){
                            bid = i;
                            min = distance;
                        }
                    }

                    biome = biomes[bid].as!Resource;

                    if(currentBiome != bid){
                        currentBiome = bid;
                        print(biome.get(gs!"name").aws!String);
                    }

                    heightMin = biome.get(gs!"heightMin").as!float;
                    heightMax = biome.get(gs!"heightMax").as!float;

                    /// Bias makes sure that the nearer we get to the biome's hieght max, the less matter there is
                    const float bias = getYBias(worldY, heightMin, heightMax);
                    placementBlock = biome.get(gs!"terrainBlock").as!int;
                    
                    const float terrainValue = terrainNoiseSet[terrainNoiseArrayPos] + bias;
                    
                    if(terrainValue < 0){
                        voxels.setVoxel(placementBlock, x, y, z, channel);
                    }
                    terrainNoiseArrayPos += 1;
                    temperatureArrayPos += 1;
                    humidityNoiseArrayPos += 1;
                }
            }
        }
    }
}
