import math

# Garmin Epoch starts at Dec 31, 1989
GARMIN_EPOCH = 1000000000 
CONV = 2147483648 / 180.0
LAT_BASE = -8.8260
LON_BASE = 115.0840

def generate_fit_csv(filename):
    with open(filename, 'w') as f:
        f.write("Type,Local Number,Message,Field 1,Value 1,Units 1,Field 2,Value 2,Units 2,Field 3,Value 3,Units 3,Field 4,Value 4,Units 4\n")
        f.write("Definition,0,file_id,serial_number,1,,time_created,1,,product,1,,type,1,,\n")
        f.write("Data,0,file_id,serial_number,12345,,time_created,1000000000,,product,1,,type,4,,\n")
        f.write("Definition,1,record,timestamp,1,,position_lat,1,,position_long,1,,speed,1,,heart_rate,1,,cadence,1,,\n")
        
        current_time = GARMIN_EPOCH
        curr_lat = LAT_BASE
        curr_lon = LON_BASE
        
        # Initial Paddle out
        for i in range(180):
            curr_lon -= 0.00001
            curr_lat += 0.000002 * math.sin(i/15.0)
            lat_semi = int(curr_lat * CONV)
            lon_semi = int(curr_lon * CONV)
            f.write(f"Data,1,record,timestamp,{current_time},,position_lat,{lat_semi},,position_long,{lon_semi},,speed,1200,mm/s,heart_rate,110,bpm,cadence,30,rpm\n")
            current_time += 1

        for wave_num in range(1, 6):
            # 1. Waiting
            wait_duration = 60 + (wave_num * 10) % 60
            for i in range(wait_duration):
                curr_lat += 0.000002 * math.sin(i/10.0)
                curr_lon += 0.000002 * math.cos(i/10.0)
                lat_semi = int(curr_lat * CONV)
                lon_semi = int(curr_lon * CONV)
                f.write(f"Data,1,record,timestamp,{current_time},,position_lat,{lat_semi},,position_long,{lon_semi},,speed,100,mm/s,heart_rate,95,bpm,cadence,0,rpm\n")
                current_time += 1
            
            # 2. Wave Ride
            wave_duration = 30 + (wave_num * 5) % 20
            speed_mult = 1.0 + (wave_num * 0.1)
            for i in range(wave_duration):
                curr_lat += 0.00002 * speed_mult
                curr_lon += 0.00008 * speed_mult
                lat_semi = int(curr_lat * CONV)
                lon_semi = int(curr_lon * CONV)
                f.write(f"Data,1,record,timestamp,{current_time},,position_lat,{lat_semi},,position_long,{lon_semi},,speed,{int(8500 * speed_mult)},mm/s,heart_rate,155,bpm,cadence,0,rpm\n")
                current_time += 1
                
            # 3. Paddle Back
            paddle_duration = 150 + (wave_num * 20) % 100
            for i in range(paddle_duration):
                dist_to_lon = curr_lon - LON_BASE
                step_lon = dist_to_lon / (paddle_duration - i) if (paddle_duration - i) > 0 else 0.00001
                curr_lon -= step_lon
                curr_lat -= 0.00001
                curr_lat += 0.000015 * math.sin(i/12.0)
                lat_semi = int(curr_lat * CONV)
                lon_semi = int(curr_lon * CONV)
                f.write(f"Data,1,record,timestamp,{current_time},,position_lat,{lat_semi},,position_long,{lon_semi},,speed,1500,mm/s,heart_rate,135,bpm,cadence,35,rpm\n")
                current_time += 1

if __name__ == "__main__":
    generate_fit_csv("/Users/guido/Git/tide_watch_app/scratch/uluwatu_surf.csv")
    print("Rich FIT CSV file generated with 5 waves.")
