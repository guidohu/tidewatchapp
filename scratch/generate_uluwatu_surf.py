import math
import datetime

# Uluwatu coordinates (Main Peak area)
LAT_START = -8.8260
LON_START = 115.0840

def write_point(f, lat, lon, time):
    f.write(f'      <trkpt lat="{lat:.6f}" lon="{lon:.6f}"><time>{time.isoformat()}Z</time></trkpt>\n')

def generate_gpx(filename):
    with open(filename, 'w') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<gpx version="1.1" creator="SurfSimulator" xmlns="http://www.topografix.com/GPX/1/1">\n')
        f.write('  <trk>\n')
        f.write('    <name>Uluwatu Surf Session - 5 Waves</name>\n')
        f.write('    <trkseg>\n')
        
        current_time = datetime.datetime(2026, 5, 13, 8, 0, 0)
        curr_lat = LAT_START
        curr_lon = LON_START
        
        # Initial Paddle out
        for i in range(180):
            curr_lon -= 0.00001
            curr_lat += 0.000002 * math.sin(i/15.0) # Wiggle
            write_point(f, curr_lat, curr_lon, current_time)
            current_time += datetime.timedelta(seconds=1)

        for wave_num in range(1, 6):
            # 1. Waiting / Drifting (1-2 minutes)
            wait_duration = 60 + (wave_num * 10) % 60
            for i in range(wait_duration):
                curr_lat += 0.000002 * math.sin(i/10.0)
                curr_lon += 0.000002 * math.cos(i/10.0)
                write_point(f, curr_lat, curr_lon, current_time)
                current_time += datetime.timedelta(seconds=1)
            
            # 2. Wave Ride (25-45 seconds)
            wave_duration = 30 + (wave_num * 5) % 20
            speed_mult = 1.0 + (wave_num * 0.1)
            for i in range(wave_duration):
                curr_lat += 0.00002 * speed_mult
                curr_lon += 0.00008 * speed_mult
                write_point(f, curr_lat, curr_lon, current_time)
                current_time += datetime.timedelta(seconds=1)
                
            # 3. Paddle Back (Non-linear, wiggly)
            paddle_duration = 150 + (wave_num * 20) % 100
            for i in range(paddle_duration):
                # Move back towards LON_START
                dist_to_lon = curr_lon - LON_START
                step_lon = dist_to_lon / (paddle_duration - i) if (paddle_duration - i) > 0 else 0.00001
                curr_lon -= step_lon
                
                # Wiggle in Lat
                curr_lat -= 0.00001 # General trend back
                curr_lat += 0.000015 * math.sin(i/12.0) # Wiggly path
                
                write_point(f, curr_lat, curr_lon, current_time)
                current_time += datetime.timedelta(seconds=1)

        f.write('    </trkseg>\n')
        f.write('  </trk>\n')
        f.write('</gpx>\n')

if __name__ == "__main__":
    generate_gpx("/Users/guido/Git/tide_watch_app/scratch/uluwatu_surf.gpx")
    print("Rich GPX file generated with 5 waves.")
