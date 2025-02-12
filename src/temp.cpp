#include <iostream>
#include <fstream>

#define SCREEN_WIDTH 640
#define SCREEN_HEIGHT 480
#define BALL_SIZE 10
#define PADDLE_WIDTH 10
#define PADDLE_HEIGHT 60
#define BALL_SPEED 2
#define PADDLE_SPEED 2

using namespace std;

bool in_paddle(int i, int j, int current, int op_current){
    if((i >= op_current && i < op_current+PADDLE_HEIGHT && j >= 0 && j < PADDLE_WIDTH) || (i >= current && i < current+PADDLE_HEIGHT && j >= SCREEN_WIDTH-PADDLE_WIDTH && j < SCREEN_WIDTH)){
        return true;
    }
    return false;
}

bool in_ball(int i, int j, int ball_x, int ball_y){
    if(j >= ball_x && j <= ball_x+BALL_SIZE && i >= ball_y && i <= ball_y+BALL_SIZE){
        return true;
    }
    return false;
}

int main(){
    // Ball direction
    int ball_dir_x = 1; // 1 for right, 0 for left
    int ball_dir_y = 1; // 1 for down, 0 for up

    // Game Score
    int game_score = 0;

    // Ball position
    int ball_x = 320;
    int ball_y = 240; // 10-bit positions for the ball (up to 640 for x and 480 for y)

    // Paddle position
    int paddle_y = SCREEN_HEIGHT / 2; // 10-bit position for the paddle (up to 480 for y)

    // Opponent Paddle position
    int op_paddle_y = SCREEN_HEIGHT / 2; // 10-bit position for the opposing paddle (up to 480 for y)

    ofstream render("render.txt");

    for(int i = 0; i < SCREEN_HEIGHT; ++i){
        for(int j = 0; j < SCREEN_WIDTH; ++j){
            if(in_paddle(i, j, paddle_y, op_paddle_y) || in_ball(i, j, ball_x, ball_y)){
                render << '%';
            }
            else{
                render << ' ';
            }
        }
        render << '\n';
    }
}
